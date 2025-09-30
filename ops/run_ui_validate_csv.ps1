param(
  [string]$BaseUrl     = "http://127.0.0.1:8010",
  [string]$JobsCsv     = "ops/ui_jobs.csv",
  [string]$BaselineDir = "targets\reference",
  [string]$AlertsDir   = "_otokodlama\alerts"
)

$ErrorActionPreference = "Stop"
$null = New-Item -ItemType Directory -Force -Path "ops\flows",$BaselineDir,"_otokodlama\out",$AlertsDir | Out-Null
$env:BASE_URL = $BaseUrl

# İdempotent redirect fix
Get-ChildItem ops\flows -Filter *equipment*.flow -ErrorAction SilentlyContinue | ForEach-Object {
  (Get-Content $_.FullName -Raw) `
    -replace 'GOTO\s+/admin/maintenance/equipment/(\s*)$', 'GOTO /admin/maintenance/equipment/_direct/$1' `
  | Set-Content -LiteralPath $_.FullName -Encoding UTF8
}

function New-UiBaselineAndValidate {
param(
  [Parameter(Mandatory=$true)][string]$Key,
  [Parameter(Mandatory=$true)][string]$Url,
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

# === CSV oku (yorum/boş satırları atla) ve çalıştır ===
if (-not (Test-Path $JobsCsv)) { throw "Jobs CSV not found: $JobsCsv" }

$rows =
  Get-Content $JobsCsv |
  Where-Object { $_ -match '\S' -and -not ($_.Trim().StartsWith('#')) } |
  ConvertFrom-Csv

$results = foreach($r in $rows){

  # null-safe alanlar
  $key     = ('' + $r.Key).Trim()
  $url     = ('' + $r.Url).Trim()
  $ocrStr  = ('' + $r.OCR).Trim().ToLower()
  $recStr  = ('' + $r.Recall).Trim()
  $minStr  = ('' + $r.MinTokenLen).Trim()
  $sel     = if([string]::IsNullOrWhiteSpace(('' + $r.WaitSelector))) {
               'css=:is(form#changelist-form,table#result_list,#content-main,#content,body)'
             } else { ('' + $r.WaitSelector) }

  if ([string]::IsNullOrWhiteSpace($key) -or $key.StartsWith('#')) { continue }
  if ([string]::IsNullOrWhiteSpace($url)) { continue }

  $ocr = @('yes','true','1','y') -contains $ocrStr

  $rec = 0.90
  $tmpD = 0.0
  if ([double]::TryParse($recStr, [ref]$tmpD)) { $rec = $tmpD }

  $minTL = 3
  $tmpI = 0
  if ([int]::TryParse($minStr, [ref]$tmpI)) { $minTL = $tmpI }

  if($ocr){
    New-UiBaselineAndValidate -Key $key -Url $url -Recall $rec -MinTokenLen $minTL -WaitSelector $sel -UseOCR
  } else {
    New-UiBaselineAndValidate -Key $key -Url $url -Recall $rec -MinTokenLen $minTL -WaitSelector $sel
  }
}

"`n=== SUMMARY ==="
$results | Format-Table key,ok,recall,missing_count,out_json -AutoSize

if (Test-Path (Join-Path $AlertsDir 'alerts_log.csv')) {
  "`n=== Alerts (last 10) ==="
  Import-Csv (Join-Path $AlertsDir 'alerts_log.csv') -Delimiter ';' |
    Select-Object ts,key,ok,recall,misses,alert_md |
    Select-Object -Last 10 | Format-Table -AutoSize
}

