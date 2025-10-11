# REV: 1.3 | 2025-09-24 | Hash: b9028e1a | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: DJCHECK | manage.py check (soft destekli) | ID:PS1-DJC-7M4N2Q9X
Param(
  [string]$Settings = "core.settings",
  [switch]$Soft
)
$ErrorActionPreference = "Stop"

if (!(Test-Path ".\manage.py")) {
  Write-Host "manage.py yok; atlandi."
  exit 0
}

$here = (Get-Location).Path
$env:PYTHONPATH = "$here"
$env:DJANGO_SETTINGS_MODULE = $Settings

try {
  python -c "import sys; print('Python OK', sys.version)"
  python -c "import django; print('Django OK', django.get_version())"
  python manage.py check -v 2 --traceback
  Write-Host "Django check OK"
} catch {
  Write-Host "Django check FAILED:"
  Write-Host $_
  if ($Soft) { exit 0 } else { throw }
}
# <<< BLOK SONU: ID:PS1-DJC-7M4N2Q9X
