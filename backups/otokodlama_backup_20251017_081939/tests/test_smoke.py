# REV: 1.1 | 2025-09-25 | Hash: ccea333a | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: TEST | Django check | ID:PY-TST-SMK-8D4F2K7M
import os
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")

def test_django_checks_importable():
    # Basit import testi; manage.py check'i ileride ekleriz
    __import__("django")
# <<< BLOK SONU: ID:PY-TST-SMK-8D4F2K7M
