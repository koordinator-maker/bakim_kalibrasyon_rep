param(
  [string[]]$Filter = @("*"),
  [switch]$LinkSmoke,
  [string]$BaseUrl    = "http://127.0.0.1:8010",
  [int]   $SmokeDepth = 1,
  [int]   $SmokeLimit = 150,
  [string]$ExtraArgs  = ""
)

if ($Filter -is [string]) {
  if ($Filter -match ",") { $Filter = $Filter -split "," | ForEach-Object { $_.Trim() } }
  else { $Filter = @($Filter) }
}
elseif ($Filter.Count -eq 1 -and $Filter[0] -match ",") {
  $Filter = $Filter[0] -split "," | ForEach-Object { $_.Trim() }
}

Write-Host ("[multi] Filters: {0}" -f ($Filter -join ", ")) -ForegroundColor Cyan

foreach($pat in $Filter){
  if ([string]::IsNullOrWhiteSpace($pat)) { continue }
  Write-Host ("[multi] Running pattern: {0}" -f $pat) -ForegroundColor Yellow

  $argList = @(
    '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
    '-File','ops\run_backlog.ps1',
    '-Filter', $pat,
    '-BaseUrl', $BaseUrl,
    '-SmokeDepth', $SmokeDepth,
    '-SmokeLimit', $SmokeLimit,
    '-ExtraArgs', $ExtraArgs
  )
  if ($LinkSmoke.IsPresent) { $argList += '-LinkSmoke' }

  powershell @argList
}
