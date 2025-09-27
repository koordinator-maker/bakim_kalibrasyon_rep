# REV: 1.1 | 2025-09-25 | Hash: 9d3d12bb | ParÃ§a: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-D2RZ41ZJ
# -*- coding: utf-8 -*-
# Ã–zel bakÄ±m/kalibrasyon ortamÄ±
from .settings import *  # projedeki ortak ayarlarÄ± iÃ§e al

# Bu ortamda kullanÄ±lacak URLConf
# <<< BLOK SONU: ID:PY-IMP-D2RZ41ZJ
# >>> BLOK: SETTINGS | Proje ayarlari | ID:PY-SET-P3NAYWXZ
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

