@echo off
setlocal
cd /d "%~dp0"

set "_PS7=%ProgramFiles%\PowerShell\7\pwsh.exe"
set "_PS5=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if exist "%_PS7%" (
  "%_PS7%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "tools\pipeline_hold.ps1"
) else (
  "%_PS5%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "tools\pipeline_hold.ps1"
)

echo.
echo (debug) Pencereyi kapatmak icin bir tusa basin...
pause >nul
exit /b 0
