# REV: 1.1 | 2025-09-24 | Hash: c82f836a | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: DJCHECK | manage.py check | ID:PS1-DJC-7M4N2Q9X
$ErrorActionPreference = "Stop"
if (!(Test-Path ".\manage.py")) { Write-Host "manage.py yok; atlandi."; exit 0 }
$env:DJANGO_SETTINGS_MODULE = "core.settings"
python manage.py check -v 0
Write-Host "Django check OK"
# <<< BLOK SONU: ID:PS1-DJC-7M4N2Q9X
