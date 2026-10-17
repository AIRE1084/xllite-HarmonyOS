[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$HapPath,
  [string]$ExpectedBundle = 'com.xjit.app.acceptance',
  [int]$ExpectedMinApi = 60100023,
  [int]$ExpectedTargetApi = 260000026,
  [string]$DevEcoRoot = 'D:\data\devecostudionext\DevEco Studio'
)
$ErrorActionPreference = 'Stop'
if ($ExpectedBundle -eq 'com.xjit.app') { throw 'Only independent acceptance artifacts are supported' }
$resolved = (Resolve-Path -LiteralPath $HapPath).Path
$hash = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
$zip = [System.IO.Compression.ZipFile]::OpenRead($resolved)
try {
  $entries = @($zip.Entries | Where-Object FullName -eq 'module.json')
  if ($entries.Count -ne 1) { throw 'Expected exactly one module.json' }
  $reader = [IO.StreamReader]::new($entries[0].Open())
  try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
} finally { $zip.Dispose() }
if ($manifest.app.bundleName -cne $ExpectedBundle) { throw 'Acceptance bundle identity mismatch' }
if ($manifest.app.minAPIVersion -ne $ExpectedMinApi) { throw 'Minimum API mismatch' }
if ($manifest.app.targetAPIVersion -ne $ExpectedTargetApi) { throw 'Target API mismatch' }
$java = Join-Path $DevEcoRoot 'jbr\bin\java.exe'
$signer = Join-Path $DevEcoRoot 'sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar'
$evidence = Join-Path $PSScriptRoot '..\.wolf\artifact-verification'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$run = [guid]::NewGuid().ToString('N')
& $java -jar $signer verify-app -inFile $resolved -outCertChain (Join-Path $evidence "$run.cer") -outProfile (Join-Path $evidence "$run.p7b")
if ($LASTEXITCODE -ne 0) { throw 'HAP signature verification failed' }
if ((Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash -ne $hash) { throw 'Artifact changed during verification' }
[ordered]@{ bundleName=$manifest.app.bundleName; minAPIVersion=$manifest.app.minAPIVersion; targetAPIVersion=$manifest.app.targetAPIVersion; sha256=$hash; signatureVerified=$true } | ConvertTo-Json
