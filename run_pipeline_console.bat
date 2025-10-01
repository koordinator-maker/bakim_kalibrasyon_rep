@echo off
setlocal
cd /d "%~dp0"

rem Tercih: PowerShell 7, yoksa Windows PowerShell
set "_PS7=%ProgramFiles%\PowerShell\7\pwsh.exe"
set "_PS5=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if exist "%_PS7%" (
  start "OTOKODLAMA Pipeline" "%_PS7%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "tools\pipeline_hold.ps1"
) else (
  start "OTOKODLAMA Pipeline" "%_PS5%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "tools\pipeline_hold.ps1"
)

exit /b 0
