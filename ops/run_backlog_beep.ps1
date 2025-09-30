# Rev: 2025-10-01 beep-fallback
param(
  [string]$FlowsDir = "ops\flows",
  [string]$OutDir   = "_otokodlama\out",
  [string]$Filter   = "*",
  [string]$BaseUrl  = "http://127.0.0.1:8010"
)
$ErrorActionPreference = "Stop"

$root = & git rev-parse --show-toplevel 2>$null
if (-not $root) { throw "Git repo not found. Run from repo root." }
Set-Location $root
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Play-Ok {
  try { [Console]::Beep(880,120) } catch {}
}

if (-not (Test-Path $FlowsDir)) { throw ("Flows directory not found: {0}. Run ops\gen_from_backlog.ps1 first." -f $FlowsDir) }
$flows = Get-ChildItem -Path $FlowsDir -Filter "$Filter.flow" -File -ErrorAction Stop | Sort-Object Name
if (-not $flows) { Write-Host ("[warn] No matching flows for filter: {0}" -f $Filter) -ForegroundColor Yellow; exit 0 }

foreach ($f in $flows) {
  Write-Host ("==> Running: {0}" -f $f.Name) -ForegroundColor Cyan
  $jsonOut = Join-Path $OutDir ($f.BaseName + ".json")
  $cmd = "powershell -ExecutionPolicy Bypass -File ops\run_and_guard.ps1 -Flow `"{0}`" -BaseUrl `"{1}`" -OutPath `"{2}`"" -f $f.FullName, $BaseUrl, $jsonOut
  cmd /c $cmd
  if ($LASTEXITCODE -ne 0) { Write-Host ("[err] {0} exit={1}" -f $f.Name, $LASTEXITCODE) -ForegroundColor Red; exit 1 }
  Play-Ok
  Write-Host ("[ok] {0}" -f $f.Name) -ForegroundColor Green
}
Write-Host "[ok] All flows passed." -ForegroundColor Green
