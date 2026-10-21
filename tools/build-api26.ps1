[CmdletBinding()]
param(
  [string]$DevEcoRoot = 'D:\data\devecostudionext\DevEco Studio',
  [string]$BuildRoot = 'D:\XJITApp-api26-build',
  [string]$NodeModulesPath = '',
  [ValidatePattern('^[a-z0-9-]*$')][string]$EvidenceName = '',
  [switch]$Incremental
)
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$stageRoot = [IO.Path]::GetFullPath($BuildRoot).TrimEnd('\')
if ($stageRoot -match '[^\x00-\x7F]' -or $stageRoot -eq $sourceRoot -or $stageRoot.StartsWith($sourceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Use an independent ASCII build directory; the API 26 builder resolves junctions to the original path.'
}
$node = Join-Path $DevEcoRoot 'tools\node\node.exe'
$hvigor = Join-Path $DevEcoRoot 'tools\hvigor\bin\hvigorw.js'
$sdkRoot = Join-Path $DevEcoRoot 'sdk'
$javaRoot = Join-Path $DevEcoRoot 'jbr'
foreach ($required in @($node, $hvigor, (Join-Path $sdkRoot 'default\sdk-pkg.json'), (Join-Path $javaRoot 'bin\java.exe'))) {
  if (-not (Test-Path -LiteralPath $required)) { throw "Existing tool not found: $required. No download or installation was attempted." }
}
if (-not $NodeModulesPath) {
  $cacheRoot = Join-Path $env:USERPROFILE '.hvigor\project_caches'
  if (Test-Path -LiteralPath $cacheRoot) {
    foreach ($candidate in (Get-ChildItem -LiteralPath $cacheRoot -Directory)) {
      $modules = Join-Path $candidate.FullName 'workspace\node_modules'
      $plugin = Join-Path $modules '@ohos\hvigor-ohos-plugin\package.json'
      $core = Join-Path $modules '@ohos\hvigor\package.json'
      if ((Test-Path -LiteralPath $plugin) -and (Test-Path -LiteralPath $core)) {
        $pluginVersion = (Get-Content -LiteralPath $plugin -Raw | ConvertFrom-Json).version
        $coreVersion = (Get-Content -LiteralPath $core -Raw | ConvertFrom-Json).version
        if ($pluginVersion -eq '6.26.8' -and $coreVersion -eq '6.26.8') { $NodeModulesPath = $modules; break }
      }
    }
  }
}
foreach ($package in @('@ohos\hvigor-ohos-plugin\package.json','@ohos\hvigor\package.json')) {
  if (-not $NodeModulesPath -or -not (Test-Path -LiteralPath (Join-Path $NodeModulesPath $package))) { throw 'Existing Hvigor 6.26.8 cache not found. No dependency installation was attempted.' }
  if ((Get-Content -LiteralPath (Join-Path $NodeModulesPath $package) -Raw | ConvertFrom-Json).version -ne '6.26.8') { throw 'The existing Hvigor cache must be version 6.26.8.' }
}
if ((Test-Path -LiteralPath $stageRoot) -and ((Get-Item -LiteralPath $stageRoot).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  throw 'The build directory must be a real directory, not a junction or symbolic link.'
}
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
$marker = Join-Path $stageRoot '.codex-xjit-build'
if (Test-Path -LiteralPath $marker) {
  if ((Get-Content -LiteralPath $marker -Raw).Trim() -ne $sourceRoot) { throw 'Build directory belongs to a different project.' }
} elseif ((Get-ChildItem -LiteralPath $stageRoot -Force | Measure-Object).Count -gt 0) {
  throw 'The build directory is nonempty and has no project marker. Select an empty ASCII directory.'
} else { Set-Content -LiteralPath $marker -Value $sourceRoot -Encoding utf8 }
$inputs = [Collections.Generic.List[string]]::new()
foreach ($directory in @('AppScope','entry\src','hvigor')) {
  Get-ChildItem -LiteralPath (Join-Path $sourceRoot $directory) -Recurse -File | ForEach-Object { $inputs.Add($_.FullName.Substring($sourceRoot.Length + 1)) }
}
foreach ($file in @('entry\build-profile.json5','entry\hvigorfile.ts','entry\oh-package.json5','hvigorfile.ts','build-profile.json5','oh-package.json5','local.properties')) { $inputs.Add($file) }
# Per-file copy prevents Copy-Item from nesting directories on repeated builds.
$inputHashes = @()
foreach ($relative in $inputs) {
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
  $sourceHash = (Get-FileHash -LiteralPath (Join-Path $sourceRoot $relative) -Algorithm SHA256).Hash
  Copy-Item -LiteralPath (Join-Path $sourceRoot $relative) -Destination $destination -Force
  if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $sourceHash) { throw "Source changed during snapshot: $relative" }
  $inputHashes += [ordered]@{ path = $relative; sha256 = $sourceHash }
}
Set-Content -LiteralPath (Join-Path $stageRoot 'local.properties') -Value ('sdk.dir=' + $sdkRoot.Replace('\','/')) -Encoding utf8
$recordRoot = Join-Path $sourceRoot '.wolf'
if ($EvidenceName) { $recordRoot = Join-Path $recordRoot $EvidenceName }
New-Item -ItemType Directory -Path $recordRoot -Force | Out-Null
$previousSdk = $env:DEVECO_SDK_HOME
$previousJava = $env:JAVA_HOME
$previousNodePath = $env:NODE_PATH
try {
  $env:DEVECO_SDK_HOME = $sdkRoot.Replace('\','/')
  $env:JAVA_HOME = $javaRoot.Replace('\','/')
  $env:NODE_PATH = $NodeModulesPath
  Push-Location -LiteralPath $stageRoot
  try {
    # Hvigor writes ArkTS warnings to stderr. With EAP=Stop, PowerShell 5.1 turns each
    # native stderr line into a terminating NativeCommandError, so keep EAP=Continue for
    # the hvigor invocations and rely on $LASTEXITCODE plus the explicit output checks.
    $previousEap = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      if (-not $Incremental) {
        & $node $hvigor clean --no-daemon --no-parallel 2>&1 | Tee-Object -FilePath (Join-Path $recordRoot 'build-api26-clean.log') | Out-Null
        $cleanExit = $LASTEXITCODE
        if ($cleanExit -ne 0) { throw "Hvigor clean failed ($cleanExit); no old package was copied." }
      }
      $buildStarted = Get-Date
      & $node $hvigor --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon --no-parallel 2>&1 | Tee-Object -FilePath (Join-Path $recordRoot 'build-api26.log') | Out-Null
      $buildExit = $LASTEXITCODE
      if ($buildExit -ne 0) { throw "API 26 build failed (exit $buildExit); no package was copied." }
    } finally { $ErrorActionPreference = $previousEap }
  } finally { Pop-Location }
  $hap = Join-Path $stageRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
  if (-not (Test-Path -LiteralPath $hap)) { throw 'Successful build did not produce an unsigned HAP.' }
  if (-not $Incremental -and (Get-Item -LiteralPath $hap).LastWriteTime -lt $buildStarted.AddSeconds(-2)) { throw 'Package timestamp predates the clean build.' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($hap)
  try {
    $moduleEntry = $archive.GetEntry('module.json')
    if ($null -eq $moduleEntry) { throw 'HAP module.json not found.' }
    $reader = [IO.StreamReader]::new($moduleEntry.Open())
    try { $moduleInfo = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($moduleInfo.app.minAPIVersion -ne 60100023 -or $moduleInfo.app.targetAPIVersion -ne 260000026) { throw 'HAP minimum/target API does not match minimum API 23 and target API 26.' }
  } finally { $archive.Dispose() }
  $outputRoot = Join-Path $sourceRoot 'entry\build\default\outputs\default'
  New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
  foreach ($name in @('entry-default-unsigned.hap', 'pack.info')) {
    $builtFile = Join-Path (Split-Path $hap -Parent) $name
    if (Test-Path -LiteralPath $builtFile) { Copy-Item -LiteralPath $builtFile -Destination (Join-Path $outputRoot $name) -Force }
  }
  $deliveredHap = Join-Path $outputRoot 'entry-default-unsigned.hap'
  $hash = (Get-FileHash -LiteralPath $hap -Algorithm SHA256).Hash
  if ((Get-FileHash -LiteralPath $deliveredHap -Algorithm SHA256).Hash -ne $hash) { throw 'Copied HAP integrity verification failed.' }
  $sourceDrift = @($inputHashes | Where-Object { (Get-FileHash -LiteralPath (Join-Path $sourceRoot $_.path) -Algorithm SHA256).Hash -ne $_.sha256 } | ForEach-Object { $_.path })
  [ordered]@{
    builtAt = (Get-Date).ToString('o'); sourceRoot = $sourceRoot; stageRoot = $stageRoot
    devEcoRoot = $DevEcoRoot; nodeModulesPath = $NodeModulesPath
    minimumApi = 23; targetApi = 26; compileSdk = $moduleInfo.app.compileSdkVersion
    hap = $deliveredHap; bytes = (Get-Item -LiteralPath $deliveredHap).Length; sha256 = $hash; inputs = $inputHashes; sourceDrift = $sourceDrift
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $recordRoot 'build-api26-inputs.json') -Encoding utf8
  Write-Output "Unsigned HAP: $deliveredHap"
  Write-Output "SHA-256: $hash"
} finally {
  $env:DEVECO_SDK_HOME = $previousSdk
  $env:JAVA_HOME = $previousJava
  $env:NODE_PATH = $previousNodePath
}
