@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul

REM Bu .bat sadece yeni bir PowerShell penceresi acip PS1'i calistirir.
REM Parametreleri oldugu gibi iletir. Or: run_maintenance_dev.bat seed doctor

set SCRIPT_DIR=%~dp0
set PS1=%SCRIPT_DIR%run_maintenance_dev.ps1

if not exist "%PS1%" (
  echo [ERR] PS1 bulunamadi: %PS1%
  echo [TIP] Dosyayi C:\dev\bakim_kalibrasyon altina koyun.
  pause
  exit /b 1
)

REM Windows PowerShell ile ac (ayri pencere, NoExit)
start "Bakim & Kalibrasyon Dev" powershell -NoExit -ExecutionPolicy Bypass -File "%PS1%" %*

REM Alternatif: Windows Terminal varsa asagidaki satiri acabilirsiniz
REM start "" wt -w 0 nt -d "C:\dev\bakim_kalibrasyon" powershell -NoExit -ExecutionPolicy Bypass -File "%PS1%" %*

exit /b 0
