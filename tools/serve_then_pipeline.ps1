# REV: 1.0 | 2025-09-25 | Hash: 7b3e92ad | Parça: 1/1
param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000
)
$ErrorActionPreference = "Stop"

# Yol/ortam
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir "..")
$VenvPy    = Join-Path $RepoRoot "venv\Scripts\python.exe"
if (!(Test-Path $VenvPy)) { throw "Venv bulunamadı: $VenvPy" }

$env:PATH                   = (Join-Path $RepoRoot "venv\Scripts") + ";" + $env:PATH
$env:PYTHONPATH             = $RepoRoot
$env:DJANGO_SETTINGS_MODULE = "core.settings"

# Config & hedef ekran görüntüsü
$cfgPath = Join-Path $RepoRoot "pipeline.config.json"
if (!(Test-Path $cfgPath)) { throw "pipeline.config.json yok: $cfgPath" }
try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json } catch { throw "pipeline.config.json geçersiz JSON." }

$targetPng = Join-Path $RepoRoot $cfg.target_screenshot
if (!(Test-Path $targetPng)) {
  $shotsDir = Join-Path $RepoRoot $cfg.screenshots_dir
  if (Test-Path $shotsDir) {
    $latest = Get-ChildItem $shotsDir -Filter *.png | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
      New-Item -ItemType Directory -Force -Path (Split-Path $targetPng) | Out-Null
      Copy-Item $latest.FullName $targetPng -Force
      Write-Host "==> Target oluşturuldu: $targetPng"
    }
  }
}

# Sunucu
Write-Host "==> runserver başlatılıyor..."
$runArgs = @("manage.py","runserver","$BindHost`:$Port","--noreload")
$server  = Start-Process -FilePath $VenvPy -ArgumentList $runArgs -PassThru -WindowStyle Hidden -WorkingDirectory $RepoRoot

# Port bekleme
$ok = $false
for($i=1; $i -le 60; $i++){
  if (Test-NetConnection $BindHost -Port $Port -InformationLevel Quiet) { $ok = $true; break }
  Start-Sleep -Milliseconds 500
}
if(-not $ok){
  try { if($server -and !$server.HasExited){ $server | Stop-Process -Force } } catch {}
  throw "runserver portu (${BindHost}:$Port) açılmadı."
}

# Pipeline
Write-Host "==> pipeline"
. (Join-Path $RepoRoot "tools\run_pipeline_venv.ps1")

# Sunucuyu kapat
Write-Host "==> runserver kapatılıyor..."
try { if($server -and !$server.HasExited){ $server | Stop-Process -Force } } catch {}

# Son rapor
$outRoot = Join-Path $RepoRoot "_otokodlama\out"
if (Test-Path $outRoot) {
  $last = Get-ChildItem $outRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($last) {
    $lay = Join-Path $last.FullName "layout_report.json"
    if (Test-Path $lay) {
      Write-Host "==> layout_report.json:"
      Get-Content $lay -Raw | Write-Host
    } else {
      Write-Host "layout_report.json bulunamadı."
    }
  } else {
    Write-Host "_otokodlama\out altında klasör yok."
  }
} else {
  Write-Host "_otokodlama\out bulunamadı."
}

Write-Host "[ALL DONE]"
