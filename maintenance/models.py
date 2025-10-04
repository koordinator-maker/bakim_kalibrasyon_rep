from django.db import models
from django.utils.translation import gettext_lazy as _

class Department(models.Model):
    """Departman modelini tanÃ„Â±mlar."""
    name = models.CharField(_("Departman AdÃ„Â±"), max_length=100, unique=True)
    
    class Meta:
        verbose_name = _("Departman")
        verbose_name_plural = _("Departmanlar")

    def __str__(self):
        return self.name

class Equipment(models.Model):
    """BakÃ„Â±m ve kalibrasyon takibi yapÃ„Â±lacak ekipmanlarÃ„Â± tanÃ„Â±mlar."""
    
    # Zorunlu alanlar
    name = models.CharField(_("Ekipman AdÃ„Â±"), max_length=200)
    
    # DÃƒÅ“ZELTÃ„Â°LDÃ„Â°: unique=True kÃ„Â±sÃ„Â±tlamasÃ„Â±, gÃƒÂ¶ÃƒÂ§ hatasÃ„Â±nÃ„Â± ÃƒÂ¶nlemek iÃƒÂ§in kaldÃ„Â±rÃ„Â±ldÃ„Â±.
    serial_number = models.CharField(max_length=120, unique=True, blank=True, null=True)