param([string]$HapPath = 'D:\XJITApp-api23-login-simulator\entry\build\default\outputs\default\entry-default-signed.hap')
$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'verify-acceptance-artifact.ps1'
if (!(Test-Path -LiteralPath $validator)) { throw 'Acceptance artifact validator is missing' }
& $validator -HapPath $HapPath
$rejected = $false
try { & $validator -HapPath $HapPath -ExpectedMinApi 999 } catch { $rejected = $true }
if (!$rejected) { throw 'Wrong minimum API was accepted' }
$rejected = $false
try { & $validator -HapPath $HapPath -ExpectedBundle 'com.xjit.app' } catch { $rejected = $true }
if (!$rejected) { throw 'Production bundle expectation was accepted' }
Write-Output 'PASS signed acceptance identity, API gate and negative cases'
