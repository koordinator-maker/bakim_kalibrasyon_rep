param(
  [string]$BaseUrl      = "http://127.0.0.1:8010",
  [string]$JobsCsv      = "ops/ui_jobs.csv",
  [string]$BaselineDir  = "targets\reference",
  [string]$AlertsDir    = "_otokodlama\alerts",
  [string]$StateTools   = "ops/state_tools.ps1",
  [string]$CsvRunner    = "ops/run_ui_validate_csv.ps1"
)

$ErrorActionPreference = "Stop"
. $StateTools

# Runner
powershell -ExecutionPolicy Bypass -File $CsvRunner -BaseUrl $BaseUrl -JobsCsv $JobsCsv -BaselineDir $BaselineDir -AlertsDir $AlertsDir | Out-Host

# CSV oku
if (-not (Test-Path $JobsCsv)) { throw "Jobs CSV not found: $JobsCsv" }
$rows = Get-Content $JobsCsv | Where-Object { $_ -match '\S' -and -not ($_.Trim().StartsWith('#')) } | ConvertFrom-Csv
if (-not $rows) { throw "CSV boş." }

$allOk = $true
foreach($r in $rows){
  $key = ('' + $r.Key).Trim()
  if ([string]::IsNullOrWhiteSpace($key) -or $key.StartsWith('#')) { continue }

  $outJson = Join-Path "_otokodlama\out" ("{0}_validate.json" -f $key)
  if (-not (Test-Path $outJson)) {
    $cand = Get-ChildItem "_otokodlama\out" -Filter "*$key*validate.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $outJson = $cand.FullName }
  }
  if (-not (Test-Path $outJson)) {
    Update-TestResult -Key $key -Status "FAILED" -Metrics @{} -Artifacts @{}
    $allOk = $false
    continue
  }

  $j = Get-Content $outJson -Raw | ConvertFrom-Json
  $status = if ($j.ok) { "PASSED" } else { "FAILED" }

  $lastAuto = $j.results | Where-Object { $_.cmd -eq 'AUTOVALIDATE' } | Select-Object -Last 1
  $recall = if ($lastAuto) { [double]$lastAuto.recall } else { $null }
  $missing = if ($lastAuto) { [int]$lastAuto.missing_count } else { $null }

  $screenshot = Join-Path $BaselineDir ("{0}.png" -f $key)
  $shotPath = ""
  if (Test-Path $screenshot) { $shotPath = $screenshot }

  $art = @{ out_json = $outJson; screenshot = $shotPath }
  $met = @{}
  if ($recall -ne $null) { $met.words_recall = $recall }
  if ($missing -ne $null) { $met.missing_count = $missing }

  Update-TestResult -Key $key -Status $status -Metrics $met -Artifacts $art
  if ($status -ne "PASSED") { $allOk = $false }
}

if ($allOk) {
  Advance-Pipeline -ToStage "open_pr" -Hint "Tüm UI doğrulamaları geçti → PR açılabilir."
  Write-Host "[pipeline] advanced → open_pr" -ForegroundColor Green
} else {
  Advance-Pipeline -ToStage "validate_ui_pages" -Hint "FAILED olan test(ler) var → düzeltmeler uygulayın."
  Write-Host "[pipeline] staying at validate_ui_pages (failures present)" -ForegroundColor Yellow
}

