@echo off
REM Rev: 2025-09-30 22:09 r6

setlocal

set PORT=8010
set HOST=127.0.0.1
set FILTER=*
set TIMEOUT_MS=20000
set SOUND_PROFILE=notify
set SOUND_FILE=

REM Switch to repo root
for /f "delims=" %%i in ('git rev-parse --show-toplevel 2^>NUL') do set ROOT=%%i
if not defined ROOT (
  echo [err] Git repo not found or git not in PATH.
  pause
  exit /b 1
)
cd /d "%ROOT%"

powershell -NoExit -ExecutionPolicy Bypass -File "tools\run_pipeline_debug.ps1" ^
  -BindHost "%HOST%" -Port %PORT% -StartServer ^
  -FlowsFilter "%FILTER%" -LinkSmoke -SmokeDepth 1 -SmokeLimit 200 ^
  -TimeoutMs %TIMEOUT_MS% -BaseUrl "http://%HOST%:%PORT%" ^
  -SoundProfile "%SOUND_PROFILE%" -SoundFile "%SOUND_FILE%"
