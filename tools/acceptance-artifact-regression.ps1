param([string]$HapPath = 'D:\XJITApp-api23-login-simulator\entry\build\default\outputs\default\entry-default-signed.hap')
$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'verify-acceptance-artifact.ps1'
if (!(Test-Path -LiteralPath $validator)) { throw 'Acceptance artifact validator is missing' }
& $validator -HapPath $HapPath
$rejected = $false
try { & $validator -HapPath $HapPath -ExpectedMinApi 999 } catch { if ($_.Exception.Message -ne 'Minimum API mismatch') { throw }; $rejected = $true }
if (!$rejected) { throw 'Wrong minimum API was accepted' }
$rejected = $false
try { & $validator -HapPath $HapPath -ExpectedBundle 'com.xjit.app' } catch { if ($_.Exception.Message -ne 'Only independent acceptance artifacts are supported') { throw }; $rejected = $true }
if (!$rejected) { throw 'Production bundle expectation was accepted' }
$rejected = $false
try { & $validator -HapPath $HapPath -ExpectedTargetApi 999 } catch { if ($_.Exception.Message -ne 'Target API mismatch') { throw }; $rejected = $true }
if (!$rejected) { throw 'Wrong target API was accepted' }
$rejected = $false
try { & $validator -HapPath $HapPath -ExpectedBundle 'com.xjit.app.wrong' } catch { if ($_.Exception.Message -ne 'Acceptance bundle identity mismatch') { throw }; $rejected = $true }
if (!$rejected) { throw 'Wrong independent bundle identity was accepted' }
$originalHash = (Get-FileHash -LiteralPath $HapPath -Algorithm SHA256).Hash
$evidence = Join-Path $PSScriptRoot '..\.wolf\artifact-verification'
$corrupt = Join-Path $evidence (([guid]::NewGuid().ToString('N')) + '-tampered.hap')
Copy-Item -LiteralPath $HapPath -Destination $corrupt
$archive = [IO.Compression.ZipFile]::Open($corrupt, [IO.Compression.ZipArchiveMode]::Update)
try {
  $entry = $archive.GetEntry('module.json')
  $reader = [IO.StreamReader]::new($entry.Open())
  try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
  $entry.Delete()
  $writer = [IO.StreamWriter]::new($archive.CreateEntry('module.json').Open())
  try { $writer.Write($text + ' ') } finally { $writer.Dispose() }
} finally { $archive.Dispose() }
$rejected = $false
try { & $validator -HapPath $corrupt } catch { if ($_.Exception.Message -ne 'HAP signature verification failed') { throw }; $rejected = $true }
if (!$rejected) { throw 'Tampered signature was accepted' }
if ((Get-FileHash -LiteralPath $HapPath -Algorithm SHA256).Hash -ne $originalHash) { throw 'Original HAP changed' }
$global:LASTEXITCODE = 0
Write-Output 'PASS signed acceptance identity, API gates, four configuration negatives and tampered signature'
