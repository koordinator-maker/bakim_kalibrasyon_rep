# Rev: 2025-09-30 21:30 r3

param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8010,
  [switch]$StartServer,
  [string]$DjangoSettings = "",
  [string]$FlowsFilter = "*",
  [switch]$LinkSmoke,
  [int]$SmokeDepth = 1,
  [int]$SmokeLimit = 200,
  [int]$TimeoutMs = 20000,
  [string]$BaseUrl = "",
  [string]$SoundProfile = "notify",
  [string]$SoundFile = ""
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[info] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ok]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Warning $msg }
function Write-Err($msg)  { Write-Host "[err]  $msg" -ForegroundColor Red }

# repo root
$root = & git rev-parse --show-toplevel 2>$null
if (-not $root) { throw "Git deposu bulunamadÄ±. 'git init' veya depo kÃ¶kÃ¼nden Ã§alÄ±ÅŸtÄ±rÄ±n." }
Set-Location $root

# default BaseUrl
if (-not $BaseUrl) { $BaseUrl = "http://${BindHost}:${Port}" }

# helper: wait for URL up
function Wait-UrlUp($url, $retries = 60) {
  for ($i=1; $i -le $retries; $i++) {
    try {
      $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 2
      if ($resp.StatusCode -in 200,301,302,401) { return $true }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  return $false
}

$serverProc = $null
$serverStartedHere = $false

if ($StartServer) {
  # Check if port already in use
  $inUse = (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) -ne $null
  if ($inUse) {
    Write-Warn "Port $Port zaten dinlemede. Sunucu baÅŸlatÄ±lmayacak (mevcut sÃ¼reci kullanÄ±yoruz)."
  }
  else {
    Write-Info "Django server baÅŸlatÄ±lÄ±yor: manage.py runserver ${BindHost}:${Port} (noreload)"
    if ($DjangoSettings) { $env:DJANGO_SETTINGS_MODULE = $DjangoSettings }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "powershell"
    $psi.Arguments = "-NoLogo -NoProfile -Command `"Set-Location `"$root`"; python manage.py runserver {0}:{1} --noreload`"" -f $BindHost, $Port
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $serverProc = [System.Diagnostics.Process]::Start($psi)
    if (-not $serverProc) { throw "Django server baÅŸlatÄ±lamadÄ±." }
    $serverStartedHere = $true
    Write-Info "Server PID: $($serverProc.Id)"
  }
}

# wait for health
Write-Info "Health check bekleniyor: $BaseUrl/admin/login/"
if (-not (Wait-UrlUp "$BaseUrl/admin/login/")) {
  if ($serverStartedHere -and $serverProc) { try { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue } catch {} }
  throw "Server ayakta gÃ¶rÃ¼nmÃ¼yor: $BaseUrl"
}
Write-Ok "Server hazÄ±r: $BaseUrl"

# 1) Flow Ã¼ret
Write-Info "Flow Ã¼retimi: ops/gen_from_backlog.ps1"
powershell -ExecutionPolicy Bypass -File "ops/gen_from_backlog.ps1"

# 2) Flow koÅŸum (per-flow sound)
$lmArg = if ($LinkSmoke) { "-LinkSmoke -SmokeDepth $SmokeDepth -SmokeLimit $SmokeLimit" } else { "" }
$cmd = "powershell -ExecutionPolicy Bypass -File ops\run_backlog_sound.ps1 -Filter `"$FlowsFilter`" -BaseUrl `"$BaseUrl`" -TimeoutMs $TimeoutMs $lmArg -SoundProfile `"$SoundProfile`" -SoundFile `"$SoundFile`""

Write-Info "KoÅŸu: $cmd"
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { Write-Err "KoÅŸu HATALI dÃ¶ndÃ¼ (exit: $LASTEXITCODE)"; if ($serverStartedHere -and $serverProc) { try { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue } catch {} }; exit $LASTEXITCODE }

Write-Ok "AkÄ±ÅŸlar baÅŸarÄ±yla tamamlandÄ±."

# 3) Server'Ä± kapat
if ($serverStartedHere -and $serverProc) {
  Write-Info "Server kapatÄ±lÄ±yor (PID=$($serverProc.Id))"
  try { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue } catch { Write-Warn "Server kapatÄ±lamadÄ±; manuel kapatÄ±n." }
}

Write-Ok "Bitti."

