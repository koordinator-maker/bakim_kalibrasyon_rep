# REV: 1.1 | 2025-09-25 | Hash: aa64b9dc | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-BA97B7DG
# <<< BLOK SONU: ID:PY-IMP-BA97B7DG
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-2Z10B8Z7
"""
WSGI config for core project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

application = get_wsgi_application()
# <<< BLOK SONU: ID:PY-HEL-2Z10B8Z7
