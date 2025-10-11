from django.db import models
import uuid

# Manufacturer modelini ekliyoruz (Equipment modeli için ForeignKey gerektirebiliriz)
# Ancak şimdilik sadece Equipment modelindeki alanı CharField olarak tutalım
# Eğer Manufacturer ayrı bir model olsaydı, şuna benzer olurdu:
# class Manufacturer(models.Model):
#     name = models.CharField(max_length=100)
#     def __str__(self):
#         return self.name

class Equipment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    # admin.py'nin beklediği alanlar
    name = models.CharField(max_length=200, verbose_name="Ekipman Adı")
    serial_number = models.CharField(max_length=100, unique=True, verbose_name="Seri Numarası")
    location = models.CharField(max_length=100, verbose_name="Konum")
    
    # EQP-003 testi için gerekli olan ve admin.py'de eklediğimiz alan
    manufacturer = models.CharField(max_length=100, blank=True, null=True, verbose_name="Üretici Firma")

    # Diğer bakım alanları
    purchase_date = models.DateField(null=True, blank=True, verbose_name="Satın Alma Tarihi")
    last_maintenance_date = models.DateField(null=True, blank=True, verbose_name="Son Bakım Tarihi")
    next_maintenance_date = models.DateField(null=True, blank=True, verbose_name="Sonraki Bakım Tarihi")
    is_active = models.BooleanField(default=True, verbose_name="Aktif")

    class Meta:
        verbose_name = "Ekipman"
        verbose_name_plural = "Ekipmanlar"

    def __str__(self):
        return self.name
