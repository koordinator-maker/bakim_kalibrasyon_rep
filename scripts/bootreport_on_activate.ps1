# Bootreport'ı venv aktivasyonunda üretir. Logu var\bootreport-activate-YYYYmmdd-HHMMSS.log'a yazar.
param()

$PRJ = Split-Path -Parent $MyInvocation.MyCommand.Path
# dosya konumumuz /scripts ise proje kökü bir üst dizin
$PRJ = Split-Path -Parent $PRJ

$PY  = Join-Path $PRJ "venv\Scripts\python.exe"
$DT  = Get-Date -Format "yyyyMMdd-HHmmss"
$LOGDIR = Join-Path $PRJ "var"
New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null
$LOG = Join-Path $LOGDIR "bootreport-activate-$DT.log"

# Ortam
$env:BOOTREPORT_DEBUG = "0"

# settings_maintenance ile çalıştır
& $PY "$PRJ\manage.py" bootreport_dump --settings=core.settings_maintenance *>> $LOG
