# REV: 1.1 | 2025-09-24 | Hash: b04a2229 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-Y1X1MS06
# <<< BLOK SONU: ID:PY-IMP-Y1X1MS06
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-QZ5YNE7P
"""
ASGI config for core project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/asgi/
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

application = get_asgi_application()
# <<< BLOK SONU: ID:PY-HEL-QZ5YNE7P
