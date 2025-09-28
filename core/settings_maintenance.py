# -*- coding: utf-8 -*-
"""
core/settings_maintenance.py
Base settings'i miras alÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±r, 'maintenance' app'ini tekilleÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€¦Ã‚Â¸tirir ve custom admin urlconf'u tanÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±mlar.
"""

from .settings import *  # noqa


def _normalize_installed(apps):
    out = []
    seen = set()
    for app in apps:
        # 'maintenance' veya 'maintenance.apps.MaintenanceConfig' geldiÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸inde
        # tek bir canonical entry'ye indiriyoruz:
        if app in ("maintenance", "maintenance.apps.MaintenanceConfig"):
            key = "maintenance.apps.MaintenanceConfig"
        else:
            key = app
        if key not in seen:
            seen.add(key)
            out.append(key)
    return out


# TekilleÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€¦Ã‚Â¸tir
INSTALLED_APPS = _normalize_installed(INSTALLED_APPS)
if "maintenance.apps.MaintenanceConfig" not in INSTALLED_APPS:
    INSTALLED_APPS.insert(0, "maintenance.apps.MaintenanceConfig")

# Custom admin site URL'leri
ROOT_URLCONF = "core.urls"
ALLOWED_HOSTS = ['127.0.0.1', 'localhost', 'testserver']


MIDDLEWARE = [
    'core.mw_fix_equip_redirect.AdminEquipmentRedirectFixMiddleware','core.mw_no_append_admin.NoAppendSlashForAdmin']

SESSION_COOKIE_SECURE = False

CSRF_COOKIE_SECURE = False

# --- AUTO PATCH (admin redirect loop & required middleware) ---
APPEND_SLASH = False
ALLOWED_HOSTS = ['127.0.0.1','localhost','testserver']

MIDDLEWARE = [
    'core.mw_fix_equip_redirect.AdminEquipmentRedirectFixMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'core.mw_no_append_admin.NoAppendSlashForAdmin',  # CommonMiddleware yerine admin'de append_slash yok
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# --- AUTO PATCH (admin redirect loop & required middleware) ---
APPEND_SLASH = False
ALLOWED_HOSTS = ['127.0.0.1','localhost','testserver']

MIDDLEWARE = [
    'core.mw_fix_equip_redirect.AdminEquipmentRedirectFixMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# --- AUTO PATCH (fix admin redirect loop & required middleware) ---
APPEND_SLASH = False
ALLOWED_HOSTS = ['127.0.0.1','localhost','testserver']

MIDDLEWARE = [
    'core.mw_fix_equip_redirect.AdminEquipmentRedirectFixMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# --- AUTO PATCH (fix admin redirect loop & required middleware) ---
APPEND_SLASH = False
ALLOWED_HOSTS = ['127.0.0.1','localhost','testserver']

MIDDLEWARE = [
    'core.mw_fix_equip_redirect.AdminEquipmentRedirectFixMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# --- AUTO PATCH (canonical redirect middleware) ---
APPEND_SLASH = False
ALLOWED_HOSTS = ['127.0.0.1','localhost','testserver']

MIDDLEWARE = [
    'core.mw_fix_equip_redirect.AdminEquipmentRedirectFixMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    # Kanonik admin liste isteklerini erken yakala:
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]



