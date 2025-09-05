from django.apps import AppConfig

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
