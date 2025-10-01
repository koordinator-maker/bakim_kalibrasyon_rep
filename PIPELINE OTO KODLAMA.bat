@echo off
setlocal enabledelayedexpansion

REM ==== AYARLAR ====
set "BASEURL=http://127.0.0.1:8010"
set "CSV=todolist\tasks_template.csv"
set "BACKLOG=ops\backlog.json"

REM Repo köküne geç
cd /d "%~dp0"

echo ----------------------------------------------
echo [info] KOK: %CD%
echo [info] CSV : %CSV%
echo [info] BACKLOG: %BACKLOG%
echo [info] BASEURL: %BASEURL%
echo ----------------------------------------------

REM Gerekli dosyalar var mi?
if not exist "%BACKLOG%" (
  echo [ERR] %BACKLOG% bulunamadi.
  goto :fail
)
if not exist "%CSV%" (
  echo [ERR] %CSV% bulunamadi.
  goto :fail
)
if not exist "ops\merge_visual_from_tasks.ps1" (
  echo [ERR] ops\merge_visual_from_tasks.ps1 yok.
  goto :fail
)
if not exist "ops\gen_from_backlog.ps1" (
  echo [ERR] ops\gen_from_backlog.ps1 yok.
  goto :fail
)
if not exist "ops\run_backlog_beep.ps1" (
  echo [ERR] ops\run_backlog_beep.ps1 yok.
  goto :fail
)

REM venv varsa tercih et
if exist "venv\Scripts\python.exe" (
  set "PATH=%CD%\venv\Scripts;%PATH%"
  echo [info] Python venv kullaniliyor: %CD%\venv
)

echo [1/3] CSV -> backlog merge (CreateMissing aktif)
call :ps "ops\merge_visual_from_tasks.ps1" -Backlog "%BACKLOG%" -TasksCsv "%CSV%" -Backup -CreateMissing
if errorlevel 1 goto :fail

echo [2/3] Flow uretimi
call :ps "ops\gen_from_backlog.ps1"
if errorlevel 1 goto :fail

echo [3/3] Kosu (beep'li)
call :ps "ops\run_backlog_beep.ps1" -Filter "*" -BaseUrl "%BASEURL%"
set "EXITCODE=%ERRORLEVEL%"

echo.
if "%EXITCODE%"=="0" (
  echo [OK] Tum flowlar gecti.
) else (
  echo [ERR] Kosu hata ile bitti (exit=%EXITCODE%).
)

exit /b %EXITCODE%

:ps
REM -- PowerShell calistirici (WinPS 5.1 veya pwsh7)
set "_PS1=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "_PS1=%ProgramFiles%\PowerShell\7\pwsh.exe"

if /i "%_PS1:~-7%"=="pwsh.exe" (
  "%_PS1%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File %*
) else (
  "%_PS1%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File %*
)
exit /b %ERRORLEVEL%

:fail
echo.
echo [HINT] Kontrol et:
echo   - %CSV% var mi ve yol dogru mu?
echo   - PS1 dosyalari ASCII/UTF-8 (BOM'suz) mi?
echo   - PowerShell ExecutionPolicy kurumsal olarak kisitli mi?
echo   - Server %BASEURL% uzerinde acik mi?
exit /b 1
