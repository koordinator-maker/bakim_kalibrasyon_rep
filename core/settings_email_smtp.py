# REV: 1.1 | 2025-09-25 | Hash: d652bc60 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-YRK6V5KM
# -*- coding: utf-8 -*-
from __future__ import annotations

import os
from .settings_maintenance import *  # noqa

# UTF-8 AUTH LOGIN destekleyen backend
# <<< BLOK SONU: ID:PY-IMP-YRK6V5KM
# >>> BLOK: SETTINGS | Proje ayarlari | ID:PY-SET-F3WT5MEH
EMAIL_BACKEND = "core.email_backend_utf8.Utf8EmailBackend"

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.office365.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")

_use_ssl = os.environ.get("SMTP_SSL", "0").lower() in ("1", "true", "yes", "on")
_use_tls = os.environ.get("SMTP_TLS", "1").lower() in ("1", "true", "yes", "on") and not _use_ssl

EMAIL_HOST = SMTP_HOST
EMAIL_PORT = SMTP_PORT
EMAIL_HOST_USER = SMTP_USER
EMAIL_HOST_PASSWORD = SMTP_PASS
EMAIL_USE_SSL = _use_ssl
EMAIL_USE_TLS = _use_tls
EMAIL_TIMEOUT = int(os.environ.get("SMTP_TIMEOUT", "30"))

DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", SMTP_USER or "noreply@example.com")
SERVER_EMAIL = DEFAULT_FROM_EMAIL
# <<< BLOK SONU: ID:PY-SET-F3WT5MEH
