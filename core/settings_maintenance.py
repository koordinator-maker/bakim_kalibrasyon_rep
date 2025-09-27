# -*- coding: utf-8 -*-
"""
core/settings_maintenance.py
Base settings'i miras alır, 'maintenance' app'ini tekilleştirir ve custom admin urlconf'u tanımlar.
"""

from .settings import *  # noqa


def _normalize_installed(apps):
    out = []
    seen = set()
    for app in apps:
        # 'maintenance' veya 'maintenance.apps.MaintenanceConfig' geldiğinde
        # tek bir canonical entry'ye indiriyoruz:
        if app in ("maintenance", "maintenance.apps.MaintenanceConfig"):
            key = "maintenance.apps.MaintenanceConfig"
        else:
            key = app
        if key not in seen:
            seen.add(key)
            out.append(key)
    return out


# Tekilleştir
INSTALLED_APPS = _normalize_installed(INSTALLED_APPS)
if "maintenance.apps.MaintenanceConfig" not in INSTALLED_APPS:
    INSTALLED_APPS.insert(0, "maintenance.apps.MaintenanceConfig")

# Custom admin site URL'leri
ROOT_URLCONF = "core.urls"