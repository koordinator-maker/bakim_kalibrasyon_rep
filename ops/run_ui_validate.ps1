param(
  [string]$BaseUrl     = "http://127.0.0.1:8010",
  [string]$BaselineDir = "targets\reference",
  [string]$AlertsDir   = "_otokodlama\alerts"
)

$ErrorActionPreference = "Stop"
$null = New-Item -ItemType Directory -Force -Path "ops\flows",$BaselineDir,"_otokodlama\out",$AlertsDir
$env:BASE_URL = $BaseUrl

# (İdempotent) equipment redirect loop fix
Get-ChildItem ops\flows -Filter *equipment*.flow -ErrorAction SilentlyContinue | ForEach-Object {
  (Get-Content $_.FullName -Raw) `
    -replace 'GOTO\s+/admin/maintenance/equipment/(\s*)$', 'GOTO /admin/maintenance/equipment/_direct/$1' `
  | Set-Content -LiteralPath $_.FullName -Encoding UTF8
}

function New-UiBaselineAndValidate {
param(
  [Parameter(Mandatory=$true)][string]$Key,     # ex: equipment_ui_list
  [Parameter(Mandatory=$true)][string]$Url,     # ex: /admin/maintenance/equipment/_direct/
  [string]$WaitSelector = 'css=:is(form#changelist-form,table#result_list,#content-main,#content,body)',
  [double]$Recall = 0.90,
  [int]$MinTokenLen = 3,
  [switch]$UseOCR,
  [string]$IgnorePatterns = 'csrf,token,\d{2,},page_\d+,id_\d+,ts_\d+'
)
  $baselinePng = Join-Path $BaselineDir ("{0}.png" -f $Key)
  $flowBase = "ops\flows\_{0}_make_baseline.flow" -f $Key
  $flowVal  = "ops\flows\{0}_validate.flow" -f $Key

@"
COMMENT make baseline ($Key)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
GOTO $Url
WAIT SELECTOR $WaitSelector
SCREENSHOT $baselinePng
"@ | Set-Content -LiteralPath $flowBase -Encoding UTF8

  $live = if($UseOCR){"dom+ocr"} else {"dom"}
@"
COMMENT validate $Key ($live)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
GOTO $Url
WAIT SELECTOR $WaitSelector
AUTOVALIDATE key=$Key baseline=$baselinePng words_recall=$Recall live_source=$live alert_dir=$AlertsDir min_token_len=$MinTokenLen ignore_numbers=yes ignore_patterns=$IgnorePatterns
"@ | Set-Content -LiteralPath $flowVal -Encoding UTF8

  $outA = "_otokodlama\out\_{0}_make_baseline.json" -f $Key
  $outB = "_otokodlama\out\{0}_validate.json" -f $Key

  Write-Host "[run] BASELINE → $Key" -ForegroundColor Cyan
  python tools\pw_flow.py --steps $flowBase --out $outA | Out-Host

  Write-Host "[run] VALIDATE → $Key ($live)" -ForegroundColor Yellow
  python tools\pw_flow.py --steps $flowVal  --out $outB | Out-Host

  $j = Get-Content $outB -Raw | ConvertFrom-Json
  $lastAuto = $j.results | Where-Object { $_.cmd -eq 'AUTOVALIDATE' } | Select-Object -Last 1
  [pscustomobject]@{
    key           = $Key
    ok            = $j.ok
    recall        = if($lastAuto){ '{0:N2}' -f [double]$lastAuto.recall } else {''}
    missing_count = if($lastAuto){ $lastAuto.missing_count } else {''}
    out_json      = $outB
  }
}

# ====== TEST SETİ ======
$jobs = @(
  @{ Key="equipment_ui_list";   Url="/admin/maintenance/equipment/_direct/";  OCR=$false },
  @{ Key="calibration_ui_list"; Url="/admin/maintenance/calibration/_direct/";OCR=$false },
  @{ Key="admin_home_fast";     Url="/admin/";                                OCR=$false }
  # İstediğin yeni modülü aşağıya sadece Key/Url girerek ekle:
  # @{ Key="bakim_plan_ui_list"; Url="/admin/maintenance/plan/_direct/"; OCR=$false }
)

$results = foreach($j in $jobs){
  if($j.OCR){ New-UiBaselineAndValidate -Key $j.Key -Url $j.Url -UseOCR }
  else      { New-UiBaselineAndValidate -Key $j.Key -Url $j.Url }
}

"`n=== SUMMARY ==="
$results | Format-Table key,ok,recall,missing_count,out_json -AutoSize

if (Test-Path (Join-Path $AlertsDir 'alerts_log.csv')) {
  "`n=== Alerts (last 10) ==="
  Import-Csv (Join-Path $AlertsDir 'alerts_log.csv') -Delimiter ';' |
    Select-Object ts,key,ok,recall,misses,alert_md |
    Select-Object -Last 10 | Format-Table -AutoSize
}

