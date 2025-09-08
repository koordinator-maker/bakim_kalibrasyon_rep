@echo off
setlocal ENABLEDELAYEDEXPANSION

REM --- Bu .bat’in bulunduğu klasör (sondaki \ ile gelir) ---
set "HERE=%~dp0"

REM --- ROOT=HERE; eğer sonunda \ varsa kırp ---
set "ROOT=%HERE%"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM --- Konsol UTF-8 (opsiyonel) ---
chcp 65001 >nul 2>&1

REM --- Zaman damgası ve çıktı adı/yolu ---
for /f %%A in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd-HHmmss')"') do set "TS=%%A"
set "OUT_NAME=codepack_full_%TS%.txt"
set "OUT_PATH=%ROOT%\%OUT_NAME%"

REM --- Limitler (isteğe göre değiştir) ---
set "MAX_FILE_BYTES=2000000"
set "MAX_TOTAL_BYTES=5000000"
set "CHUNK_BYTES=1800000"
set "ENABLE_SPLIT=1"

REM --- EXE yolu ---
set "EXE=%ROOT%\codepack_v2.exe"
if not exist "%EXE%" (
  echo [HATA] codepack_v2.exe bulunamadi: %EXE%
  echo [IPUCU] EN_TAZE_KODLAR_GELDI.bat ve codepack_v2.exe AYNI klasorde olmali.
  pause
  exit /b 1
)

echo [INFO] ROOT : %ROOT%
echo [INFO] OUT  : %OUT_PATH%
echo.

REM --- Çalıştır (parçalama açık/kapalı) ---
if "%ENABLE_SPLIT%"=="1" (
  "%EXE%" --root "%ROOT%" --out "%OUT_PATH%" --max-file-bytes %MAX_FILE_BYTES% --max-total-bytes %MAX_TOTAL_BYTES% --split --chunk-bytes %CHUNK_BYTES%
) else (
  "%EXE%" --root "%ROOT%" --out "%OUT_PATH%" --max-file-bytes %MAX_FILE_BYTES% --max-total-bytes %MAX_TOTAL_BYTES%
)

set "RC=%ERRORLEVEL%"
echo.
echo [INFO] EXITCODE: %RC%

if NOT "%RC%"=="0" (
  echo [HATA] codepack_v2.exe hatayla cikti. (exitcode=%RC%)
  pause
  exit /b %RC%
)

echo [OK] Olusan dosya: %OUT_PATH%
echo [NOT] Parcalama aciksa %OUT_PATH%_001.txt, _002.txt ... gibi dosyalar olusur.
pause
endlocal
