@echo off
setlocal
REM Rev: 2025-10-01 beep-only

set HOST=127.0.0.1
set PORT=8010
set BASEURL=http://%HOST%:%PORT%
set FILTER=*

for /f "delims=" %%i in ('git rev-parse --show-toplevel 2^>NUL') do set ROOT=%%i
if not defined ROOT (
  echo [err] Not a git repo or Git not in PATH.
  pause
  exit /b 1
)
cd /d "%ROOT%"

REM Flow'lar? ?ret
powershell -NoLogo -ExecutionPolicy Bypass -File ops\gen_from_backlog.ps1

REM Beep'li ko?um (timeout vs. YOK)
powershell -NoLogo -ExecutionPolicy Bypass -File ops\run_backlog_beep.ps1 -Filter "%FILTER%" -BaseUrl "%BASEURL%"

set EC=%ERRORLEVEL%
if %EC% NEQ 0 (
  echo [err] Failed with exit code %EC%
  pause
  exit /b %EC%
)
echo [ok] Done (beeps played on each success).
pause
