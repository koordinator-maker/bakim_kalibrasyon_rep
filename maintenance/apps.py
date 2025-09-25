# REV: 1.1 | 2025-09-25 | Hash: 30143910 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-PTSYESDH
from django.apps import AppConfig

# <<< BLOK SONU: ID:PY-IMP-PTSYESDH
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-WP1RFCNE
class MaintenanceConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "maintenance"
    verbose_name = "Bakım Modülü"

    def ready(self):
        try:
            from .bootreport import safe_write_boot_report
            safe_write_boot_report()
        except Exception:
            pass
# <<< BLOK SONU: ID:PY-HEL-WP1RFCNE
