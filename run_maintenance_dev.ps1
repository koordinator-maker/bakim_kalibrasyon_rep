# REV: 1.0 | 2025-09-24 | Hash: ca844bfd | Parça: 1/1
#Requires -Version 5.1
param(
  [switch]$Seed,     # örn: .\run_maintenance_dev.ps1 -Seed
  [switch]$Doctor    # örn: .\run_maintenance_dev.ps1 -Doctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok($msg){ Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err($msg){ Write-Host "[ERR]  $msg" -ForegroundColor Red }

function Run-Py([string]$Code, [string]$Label = "python") {
  $tmp = [System.IO.Path]::GetTempFileName()
  $py  = [System.IO.Path]::ChangeExtension($tmp, ".py")
  Set-Content -Path $py -Value $Code -Encoding UTF8
  & python $py
  $ec = $LASTEXITCODE
  Remove-Item -Force $py,$tmp -ErrorAction SilentlyContinue
  if ($ec -ne 0) { throw "$Label failed (exitcode=$ec)" }
}

# 1) Proje klasörüne geç
$proj = "C:\dev\bakim_kalibrasyon"
if (-not (Test-Path $proj)) { Err "Proje klasoru yok: $proj"; Read-Host "Kapatmak için Enter"; exit 1 }
Set-Location $proj

# 2) venv kontrol
$act = ".\venv\Scripts\Activate.ps1"
if (-not (Test-Path $act)) {
  Err "venv bulunamadi: $act"
  Write-Host "[TIP] Olusturmak icin:  python -m venv venv" -ForegroundColor Yellow
  Read-Host "Kapatmak için Enter"
  exit 1
}

# 3) venv aktif et
. $act
if (-not $env:VIRTUAL_ENV) { Err "venv aktive edilemedi"; Read-Host "Kapatmak için Enter"; exit 1 }

# 4) Django ayari (maintenance profili)
$env:DJANGO_SETTINGS_MODULE = "core.settings_maintenance"
$env:DATABASE_URL = ""
$env:PYTHONIOENCODING = "utf-8"

# ⭐ 4.1) Proje kökünü Python yoluna ekle (core modülünü bulsun)
$env:PYTHONPATH = $proj

# 5) Hangi Python ve settings?  (GEÇİCİ .py ile)
$codeInfo = @'
import sys, os
print("PYTHON:", sys.executable)
print("CWD:", os.getcwd())
print("PYTHONPATH has proj?:", any(p.replace("\\\\","\\") == os.getcwd() for p in sys.path))
'@
Run-Py $codeInfo "python info"

$codeDjango = @'
import os, sys
# Emniyet: çalışma dizinini sys.path'e öne ekle
sys.path.insert(0, os.getcwd())
import django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", os.environ.get("DJANGO_SETTINGS_MODULE","core.settings_maintenance"))
django.setup()
from django.conf import settings
print("SETTINGS:", settings.SETTINGS_MODULE)
print("DB ENGINE:", settings.DATABASES["default"]["ENGINE"])
'@
Run-Py $codeDjango "django setup"

# 6) migrate (idempotent)
Info "migrate calisiyor..."
& python manage.py migrate --settings=$env:DJANGO_SETTINGS_MODULE
if ($LASTEXITCODE -ne 0) { throw "migrate hatasi (exitcode=$LASTEXITCODE)" }

# 7) (opsiyonel) demo veri
if ($Seed) {
  Info "seed_demo calisiyor..."
  & python manage.py seed_demo --settings=$env:DJANGO_SETTINGS_MODULE --count 80
  if ($LASTEXITCODE -ne 0) { Warn "seed_demo basarisiz (exitcode=$LASTEXITCODE)" }
}

# 8) (opsiyonel) bootreport dogrulama
if ($Doctor) {
  Info "bootreport_doctor calisiyor..."
  & python manage.py bootreport_doctor --settings=$env:DJANGO_SETTINGS_MODULE
}

# 9) server
Ok "http://127.0.0.1:8003/ adresinde baslatiliyor..."
& python manage.py runserver 127.0.0.1:8003 --settings=$env:DJANGO_SETTINGS_MODULE --noreload
