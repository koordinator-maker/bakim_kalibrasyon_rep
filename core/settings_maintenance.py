# REV: 1.1 | 2025-09-25 | Hash: 9d3d12bb | ParÃ§a: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-D2RZ41ZJ
# -*- coding: utf-8 -*-
# Ã–zel bakÄ±m/kalibrasyon ortamÄ±
# -*- coding: utf-8 -*-
# core/settings_maintenance.py  (tam içerik)

from .settings import *  # base settings'i miras al

# maintenance app'ini listede TEK kez bırak
_clean = []
_seen = set()
for app in INSTALLED_APPS:
    if app in ("maintenance", "maintenance.apps.MaintenanceConfig"):
        key = "maintenance.apps.MaintenanceConfig"
    else:
        key = app
    if key not in _seen:
        _seen.add(key)
        _clean.append(key)
INSTALLED_APPS = [a for a in _clean if a != "maintenance"]  # çıplak 'maintenance' varsa at
if "maintenance.apps.MaintenanceConfig" not in INSTALLED_APPS:
    INSTALLED_APPS.insert(0, "maintenance.apps.MaintenanceConfig")

# custom admin site urls
ROOT_URLCONF = "core.urls"


# Maintenance app MUTLAKA burada kayÄ±tlÄ± olmalÄ±
# Tercihen AppConfig yolu ile ekleyelim:
if "maintenance.apps.MaintenanceConfig" not in INSTALLED_APPS:
    INSTALLED_APPS = list(INSTALLED_APPS) + ["maintenance.apps.MaintenanceConfig"]

# (Ä°steÄŸe baÄŸlÄ±) YÃ¶netim paneli gÃ¶rÃ¼nÃ¼mÃ¼ vs. iÃ§in tema/ek ayarlar ileride gelebilir

# GeliÅŸtirme iÃ§in basit e-posta backend'i
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
DEFAULT_FROM_EMAIL = "noreply@example.com"

# Zaman dilimi/yerel ayar (projenin genelinden farklÄ± kullanmak istersen)
# TIME_ZONE = "Europe/Istanbul"
# USE_TZ = True
# <<< BLOK SONU: ID:PY-SET-P3NAYWXZ

