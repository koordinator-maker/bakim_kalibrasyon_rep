# REV: 1.0 | 2025-09-25 | Hash: a1f2c3d4 | Parça: 1/1
param()
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir "..")
$VenvPy    = Join-Path $RepoRoot "venv\Scripts\python.exe"
if (!(Test-Path $VenvPy)) { throw "Venv bulunamadı: $VenvPy" }
$env:PATH                   = (Join-Path $RepoRoot "venv\Scripts") + ";" + $env:PATH
$env:PYTHONPATH             = $RepoRoot
$env:DJANGO_SETTINGS_MODULE = "core.settings"
& $VenvPy -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('playwright') else 1)"
if ($LASTEXITCODE -ne 0) {
  Write-Host "==> Playwright kuruluyor..."
  & $VenvPy -m pip install --disable-pip-version-check -q playwright
  if ($LASTEXITCODE -ne 0) { throw "pip install playwright başarısız." }
  & $VenvPy -m playwright install chromium
  if ($LASTEXITCODE -ne 0) { throw "playwright install chromium başarısız." }
}
Write-Host "==> pipeline.ps1 çalışıyor..."
. (Join-Path $RepoRoot "pipeline.ps1")

