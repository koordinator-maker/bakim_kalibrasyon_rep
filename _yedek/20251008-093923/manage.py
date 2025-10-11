# REV: 1.1 | 2025-09-25 | Hash: 1cc1418a | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-XX3Z0KQ7
#!/usr/bin/env python
# <<< BLOK SONU: ID:PY-IMP-XX3Z0KQ7
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-JNKMP1V0
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
# <<< BLOK SONU: ID:PY-HEL-JNKMP1V0
