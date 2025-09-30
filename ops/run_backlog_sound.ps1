# Rev: 2025-09-30 rD (no --timeout hotfix)
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

# repo root
$root = & git rev-parse --show-toplevel 2>$null
if (-not $root) { throw "Git repo not found. Run from inside the repository." }
Set-Location $root

# ensure dirs
New-Item -ItemType Directory -Force $OutDir | Out-Null
New-Item -ItemType Directory -Force $ReportDir | Out-Null

# load sound helper
. "tools\sound.ps1" -SoundProfile $SoundProfile -SoundFile $SoundFile | Out-Null

# discover flows
if (-not (Test-Path $FlowsDir)) { throw ("Flows directory not found: {0}. Run ops\gen_from_backlog.ps1 first." -f $FlowsDir) }
$flows = Get-ChildItem -Path $FlowsDir -Filter "$Filter.flow" -File -ErrorAction Stop | Sort-Object Name
if (-not $flows) { Write-Host ("[warn] No matching flows for filter: {0}" -f $Filter) -ForegroundColor Yellow; exit 0 }

$fail = 0
foreach ($f in $flows) {
  Write-Host ("==> Running: {0}" -f $f.Name) -ForegroundColor Cyan

  # 1) run the flow (no --timeout hotfix)
  $jsonOut = Join-Path $OutDir ($f.BaseName + ".json")
  $cmd = "powershell -ExecutionPolicy Bypass -File ops\run_and_guard.ps1 -Flow `"{0}`" -BaseUrl `"{1}`" -OutPath `"{2}`"" -f $f.FullName, $BaseUrl, $jsonOut
  cmd /c $cmd
  if ($LASTEXITCODE -ne 0) { Write-Host ("[err] {0} exit={1}" -f $f.Name, $LASTEXITCODE) -ForegroundColor Red; $fail++; break }

  # 2) optional link smoke gating
  if ($LinkSmoke) {
    $okRedirect = "/_direct/.*"
    $smokeCmd = "powershell -ExecutionPolicy Bypass -File ops\smoke_links.ps1 -BaseUrl `"{0}`" -Start `"/admin/`" -Depth {1} -Limit {2} -OkRedirectTo `"{3}`"" -f $BaseUrl, $SmokeDepth, $SmokeLimit, $okRedirect
    cmd /c $smokeCmd
    if ($LASTEXITCODE -ne 0) { Write-Host ("[err] Link smoke failed for: {0}" -f $f.Name) -ForegroundColor Red; $fail++; break }
  }

  # 3) success sound
  Write-Host ("[ok] {0}" -f $f.Name) -ForegroundColor Green
  Play-NotifySound -SoundProfile $SoundProfile -SoundFile $SoundFile
}

if ($fail -eq 0) { Write-Host "[ok] All flows passed." -ForegroundColor Green } else { Write-Host "[err] Some flows failed." -ForegroundColor Red; exit 1 }
