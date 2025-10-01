@echo off
setlocal
cd /d "%~dp0"

rem PowerShell 7 varsa onu, yoksa Windows PowerShell
set "_PSBIN=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not exist "%_PSBIN%" set "_PSBIN=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

rem Ayrı konsolu -NoExit ile aç; pencere kapanmaz
start "OTOKODLAMA Pipeline" "%_PSBIN%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "tools\pipeline_hold.ps1"
exit /b 0
