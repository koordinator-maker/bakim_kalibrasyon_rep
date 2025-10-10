@echo off
set TASKNAME=BakimKalibrasyon_ReminderDaily
schtasks /Delete /TN "%TASKNAME%" /F
echo [OK] Silindi: %TASKNAME%
