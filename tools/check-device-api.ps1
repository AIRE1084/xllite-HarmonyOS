param(
  [Parameter(Mandatory = $true)][string]$Target,
  [int]$ExpectedApi = 23,
  [string]$HdcPath = 'D:\data\devecostudionext\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $HdcPath -PathType Leaf)) { throw 'HDC executable not found.' }
$result = & $HdcPath -t $Target shell param get const.ohos.apiversion
if ($LASTEXITCODE -ne 0) { throw "Device API query failed: $LASTEXITCODE" }
$text = ($result -join '').Trim()
$actual = 0
if (![int]::TryParse($text, [ref]$actual) -or $actual -lt 1) { throw "Invalid device API response: $text" }
Write-Output "Target=$Target ActualApi=$actual ExpectedApi=$ExpectedApi"
if ($actual -ne $ExpectedApi) { throw 'Device API mismatch; do not record this target as the requested API acceptance.' }
Write-Output 'API version gate passed. This does not prove installation, module linking or rendering.'
