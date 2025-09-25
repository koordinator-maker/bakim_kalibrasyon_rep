# REV: 1.1 | 2025-09-25 | Hash: 9d3d12bb | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-D2RZ41ZJ
# -*- coding: utf-8 -*-
# Özel bakım/kalibrasyon ortamı
from .settings import *  # projedeki ortak ayarları içe al

# Bu ortamda kullanılacak URLConf
# <<< BLOK SONU: ID:PY-IMP-D2RZ41ZJ
# >>> BLOK: SETTINGS | Proje ayarlari | ID:PY-SET-P3NAYWXZ
ROOT_URLCONF = "core.urls"

# Maintenance app MUTLAKA burada kayıtlı olmalı
# Tercihen AppConfig yolu ile ekleyelim:
if "maintenance.apps.MaintenanceConfig" not in INSTALLED_APPS:
    INSTALLED_APPS = list(INSTALLED_APPS) + ["maintenance.apps.MaintenanceConfig"]

# (İsteğe bağlı) Yönetim paneli görünümü vs. için tema/ek ayarlar ileride gelebilir

# Geliştirme için basit e-posta backend'i
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
DEFAULT_FROM_EMAIL = "noreply@example.com"

# Zaman dilimi/yerel ayar (projenin genelinden farklı kullanmak istersen)
# TIME_ZONE = "Europe/Istanbul"
# USE_TZ = True
# <<< BLOK SONU: ID:PY-SET-P3NAYWXZ
