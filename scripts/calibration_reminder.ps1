# REV: 1.0 | 2025-09-24 | Hash: 504d2bb6 | Parça: 1/1
param(
  [string]$Days = "30,60,90",
  [string]$Roles = "Bakım Yöneticisi",
  [ValidateSet("csv","xlsx","both")][string]$Attach = "both",
  [switch]$DryRun,
  [string]$Settings = "core.settings_maintenance"  # <— yeni: hangi settings kullanılacak
)

$ErrorActionPreference = "Stop"

& "$env:WINDIR\System32\chcp.com" 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"

$proj = "C:\dev\bakim_kalibrasyon"
if (-not (Test-Path $proj)) { Write-Error "[ERR] Proje klasörü yok: $proj"; exit 1 }
Set-Location $proj

$venv = ".\venv\Scripts\Activate.ps1"
if (-not (Test-Path $venv)) { Write-Error "[ERR] venv bulunamadı: $venv"; exit 1 }
. $venv

# günler
$daysList = @()
foreach ($p in $Days.Split(",")) { $p2 = $p.Trim(); if ($p2 -match '^\d+$') { $daysList += [int]$p2 } }
if ($daysList.Count -eq 0) { $daysList = @(30) }

$rolesArg  = $Roles
$attachArg = $Attach
$extraArgs = ""
if ($DryRun) { $extraArgs = "--dry-run --no-asset-emails" }

$cmd = "python manage.py calibration_reminder --days " + ($daysList -join ' ') + `
       " --roles `"${rolesArg}`" --attach $attachArg --settings=$Settings $extraArgs"

Write-Host "[INFO] Çalıştırılıyor: $cmd"
cmd /c $cmd
$ec = $LASTEXITCODE
Write-Host "[INFO] ExitCode=$ec"
exit $ec
