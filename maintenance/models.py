from django.db import models
from django.utils.translation import gettext_lazy as _

class Department(models.Model):
    """Departman modelini tanımlar."""
    name = models.CharField(_("Departman Adı"), max_length=100, unique=True)
    
    class Meta:
        verbose_name = _("Departman")
        verbose_name_plural = _("Departmanlar")

    def __str__(self):
        return self.name

class Equipment(models.Model):
    """Bakım ve kalibrasyon takibi yapılacak ekipmanları tanımlar."""
    
    # Zorunlu alanlar
    name = models.CharField(_("Ekipman Adı"), max_length=200)
    
    # DÜZELTİLDİ: unique=True kısıtlaması, göç hatasını önlemek için kaldırıldı.
    serial_number = models.CharField(_("Seri Numarası"), max_length=100) 
    
    location = models.CharField(_("Konum"), max_length=100) # Örneğin: Atölye A, Laboratuvar B
    
    # DÜZELTİLDİ: unique=True kısıtlaması, göç hatasını önlemek için kaldırıldı.
    inventory_code = models.CharField(_("Envanter Kodu"), max_length=50, blank=True, null=True) 
    
    purchase_date = models.DateField(_("Satın Alma Tarihi"), null=True, blank=True)
    
    # İlişkisel alan: Department modeli ile ilişki
    department = models.ForeignKey(
        Department, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        verbose_name=_("Departman")
    )

    class Meta:
        verbose_name = _("Ekipman")
        verbose_name_plural = _("Ekipmanlar")
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.serial_number})"
