@echo off
setlocal
chcp 65001 >nul

set PROJ=C:\dev\bakim_kalibrasyon
set PS1=%PROJ%\scripts\calibration_reminder.ps1
set TASKNAME=BakimKalibrasyon_ReminderDaily

if not exist "%PS1%" (
  echo [ERR] PS1 yok: %PS1%
  exit /b 1
)

REM GÜNLÜK 08:30
schtasks /Create /TN "%TASKNAME%" /SC DAILY /ST 08:30 ^
  /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"%PS1%\"" ^
  /F

echo [OK] Olusturuldu: %TASKNAME%
echo Test etmek icin: schtasks /Run /TN "%TASKNAME%"
echo Loglar: %PROJ%\var\calibration_reminders\logs\
