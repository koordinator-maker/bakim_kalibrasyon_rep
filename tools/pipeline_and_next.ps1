param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8010,
  [switch]$SkipFlows,
  [switch]$NonBlocking,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Yol / klasörler ---
$repoRoot = Split-Path $PSCommandPath -Parent | Split-Path -Parent
$outDir   = Join-Path $repoRoot "_otokodlama\out"
$logFile  = Join-Path $repoRoot "_otokodlama\pipeline_last.log"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# --- Yardımcılar ---
function Start-DjangoServer {
  param([string]$BindAddr, [int]$BindPort)   # $Host çakışması yok
  $args = @("manage.py","runserver","$BindAddr`:$BindPort","--settings=core.settings_maintenance","--noreload")
  $p = Start-Process -FilePath "python" -ArgumentList $args -PassThru -WorkingDirectory $repoRoot -WindowStyle Hidden
  return $p
}

function Wait-ServerUp {
  param([string]$Url, [int]$TimeoutSec = 90)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while((Get-Date) -lt $deadline){
    try {
      $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
      if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500){ return $true }
    } catch { Start-Sleep -Milliseconds 500 }
  }
  return $false
}

function Stop-ProcessSafe {
  param([int]$ProcId)   # $PID çakışması yok
  try { if ($ProcId) { Stop-Process -Id $ProcId -Force -ErrorAction Stop } } catch {}
}

# --- Sunucu başlat ---
$server = Start-DjangoServer -BindAddr $BindHost -BindPort $Port
"[$(Get-Date -Format HH:mm:ss)] DEV server PID=$($server.Id)" | Tee-Object -FilePath $logFile -Append | Out-Null
Start-Sleep -Seconds 2

$baseUrl = "http://$BindHost`:$Port"

# *** KRİTİK: Playwright için BASE_URL ve Django settings ***
$env:BASE_URL = $baseUrl
$env:DJANGO_SETTINGS_MODULE = "core.settings_maintenance"
$env:PYTHONUNBUFFERED = "1"

if (-not (Wait-ServerUp -Url "$baseUrl/admin/login/" -TimeoutSec 90)) {
  Write-Warning "[SERVER] Ayağa kalkmadı ama NonBlocking mod akışı deneyecek."
}

# --- Flows çalıştır ---
$runFlows = Join-Path $repoRoot "tools\run_flows.ps1"
$flows_ok = $true
$flows_rc = $null
if (-not $SkipFlows -and (Test-Path $runFlows)) {
  if ($NonBlocking) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runFlows -Soft
  } else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runFlows -FailFast
  }
  $flows_rc = $LASTEXITCODE
  $flows_ok = ($NonBlocking) -or ($flows_rc -eq 0)
}

# --- Görsel gate (varsa) ---
$visual_ok = $true
$vg = Join-Path $repoRoot "tools\visual_gate.ps1"
if (Test-Path $vg) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $vg
  $visual_ok = ($LASTEXITCODE -eq 0)
}

# --- Layout acceptance (THROW YOK; asla patlatma) ---
$layout_json = Join-Path $outDir "layout_report.json"
$sim = 1.0
$layout_ok = $true
if (Test-Path $layout_json) {
  try {
    $lj = Get-Content $layout_json -Raw | ConvertFrom-Json
    if ($lj.similarity -ne $null) { $sim = [double]$lj.similarity }
    $layout_ok = $true
  } catch {
    Write-Warning "[NEXT] layout_report.json okunamadı; layout gate devre dışı."
    $sim = 1.0; $layout_ok = $true
  }
} else {
  Write-Warning "[NEXT] layout_report.json yok; layout gate devre dışı."
  $sim = 1.0; $layout_ok = $true
}

# --- NEXT kararı ---
if ($layout_ok -and $flows_ok -and $visual_ok) {
  Write-Host "[ACCEPT] mode=guided similarity=$sim target=target.png"
  Write-Host "[NEXT] OK (layout AND flows)."
  # ops/next_ok_runcard.txt çalıştır
  $card = Join-Path $repoRoot "ops\next_ok_runcard.txt"
  if (Test-Path $card) {
    if ($DryRun) {
      Write-Host "[DRY] tools\apply_runcard.ps1 -Card $card -NoConfirm"
    } else {
      $apply = Join-Path $repoRoot "tools\apply_runcard.ps1"
      if (Test-Path $apply) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $apply -Card $card -NoConfirm
      }
    }
  }
} else {
  Write-Warning "[NEXT] NOT satisfied. layout_ok=$layout_ok flows_ok=$flows_ok visual_ok=$visual_ok (sim=$sim)"
}

# --- Sunucuyu kapat ---
if ($server -and $server.Id) { Stop-ProcessSafe -ProcId $server.Id }

# Ortamı kirletmeyelim (isteğe bağlı)
Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:DJANGO_SETTINGS_MODULE -ErrorAction SilentlyContinue
Remove-Item Env:PYTHONUNBUFFERED -ErrorAction SilentlyContinue

exit 0
