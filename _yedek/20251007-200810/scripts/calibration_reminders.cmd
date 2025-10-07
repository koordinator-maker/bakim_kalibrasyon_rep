@echo off
REM === Calibration reminders runner (Windows CMD wrapper) ===
REM Çalışma klasörü: bu dosyanın bulunduğu klasörün üstü = proje kökü
setlocal ENABLEDELAYEDEXPANSION

REM Script klasörü ve proje kökü
set SCRIPT_DIR=%~dp0
REM %~dp0 -> scripts\ dizini; bir üst klasöre çık
pushd "%SCRIPT_DIR%\.."

REM Log klasörü
if not exist "logs" mkdir "logs"
set LOGFILE=logs\calibration_reminders_%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%.log

REM Sanal ortam Python yolu
set PY_EXE=venv\Scripts\python.exe

REM Yönetim komutu (30 gün; maintenance ayarları)
set CMD=%PY_EXE% manage.py calibration_reminders --days 30 --settings=core.settings_maintenance

echo [START] %DATE% %TIME% >> "%LOGFILE%"
echo Running: %CMD% >> "%LOGFILE%"

REM Komutu çalıştır
%CMD% >> "%LOGFILE%" 2>&1
set ERR=%ERRORLEVEL%

echo ExitCode=%ERR% >> "%LOGFILE%"
echo [END] %DATE% %TIME% >> "%LOGFILE%"
echo. >> "%LOGFILE%"

popd
exit /b %ERR%
