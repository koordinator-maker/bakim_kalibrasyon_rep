@echo off
chcp 65001 >nul
set PROJ=C:\dev\bakim_kalibrasyon
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJ%\scripts\calibration_reminder.ps1"
