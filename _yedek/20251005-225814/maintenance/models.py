from django.db import models
from django.utils.translation import gettext_lazy as _

class Department(models.Model):
    """Departman modelini tanÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±mlar."""
    name = models.CharField(_("Departman AdÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±"), max_length=100, unique=True)
    
    class Meta:
        verbose_name = _("Departman")
        verbose_name_plural = _("Departmanlar")

    def __str__(self):
        return self.name

class Equipment(models.Model):
    """BakÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±m ve kalibrasyon takibi yapÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±lacak ekipmanlarÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â± tanÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±mlar."""
    
    # Zorunlu alanlar
    name = models.CharField(_("Ekipman AdÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±"), max_length=200)
    
    # DÃƒÆ’Ã†â€™Ãƒâ€¦Ã¢â‚¬Å“ZELTÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â°LDÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â°: unique=True kÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±sÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±tlamasÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±, gÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¶ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ hatasÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±nÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â± ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¶nlemek iÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§in kaldÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±rÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±ldÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±.
    serial_number = models.CharField(max_length=120, unique=True, blank=True, null=True)