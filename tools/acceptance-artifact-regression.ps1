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
Write-Output 'PASS signed acceptance identity, minimum/target API and four negative cases'
