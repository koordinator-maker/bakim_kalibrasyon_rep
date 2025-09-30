# Rev: 2025-09-30 21:30 r3

param(
  [string]$FlowsDir   = "ops\flows",
  [string]$OutDir     = "_otokodlama\out",
  [string]$ReportDir  = "_otokodlama\reports",
  [string]$Filter     = "*",
  [switch]$LinkSmoke,
  [int]$SmokeDepth = 1,
  [int]$SmokeLimit = 200,
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [int]$TimeoutMs = 20000,
  [string]$SoundProfile = "notify",
  [string]$SoundFile = ""
)

$ErrorActionPreference = "Stop"

# Repo root
$root = & git rev-parse --show-toplevel 2>$null
if (-not $root) { throw "Git deposu bulunamadı. Depo kökünden çalıştırın." }
Set-Location $root

# Load sound helper
. "tools\sound.ps1" -SoundProfile $SoundProfile -SoundFile $SoundFile | Out-Null

# Discover flows
if (-not (Test-Path $FlowsDir)) { throw "Flows dir yok: $FlowsDir — önce ops\gen_from_backlog.ps1 çalıştırın." }
$flows = Get-ChildItem -Path $FlowsDir -Filter "$Filter.flow" -File -ErrorAction Stop | Sort-Object Name
if (-not $flows) { Write-Warning "Eşleşen flow bulunamadı: $Filter"; exit 0 }

# Params for run_and_guard
$extra = "--timeout $TimeoutMs"
$lmArgs = ""
if ($LinkSmoke) { $lmArgs = "-LinkSmoke -SmokeDepth $SmokeDepth -SmokeLimit $SmokeLimit" }

$fail = 0
foreach ($f in $flows) {
  Write-Host "==> Running: $($f.Name)" -ForegroundColor Cyan
  $cmd = "powershell -ExecutionPolicy Bypass -File ops\run_and_guard.ps1 -Flow `"$($f.FullName)`" -BaseUrl `"$BaseUrl`" $lmArgs -ExtraArgs `"$extra`""
  cmd /c $cmd
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[ok] $($f.Name)" -ForegroundColor Green
    Play-NotifySound -SoundProfile $SoundProfile -SoundFile $SoundFile
  } else {
    Write-Host "[err] $($f.Name) exit=$LASTEXITCODE" -ForegroundColor Red
    $fail++
    break
  }
}

if ($fail -eq 0) {
  Write-Host "[ok] All flows passed." -ForegroundColor Green
} else {
  Write-Host "[err] Some flows failed." -ForegroundColor Red
  exit 1
}
