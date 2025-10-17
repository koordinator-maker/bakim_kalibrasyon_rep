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
class CalibrationAsset(models.Model):
    """Kalibrasyon yapılacak cihaz/varlık"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    asset_code = models.CharField(max_length=100, unique=True, verbose_name="Cihaz Kodu")
    asset_name = models.CharField(max_length=200, verbose_name="Cihaz Adı")
    location = models.CharField(max_length=100, blank=True, verbose_name="Lokasyon")
    brand = models.CharField(max_length=100, blank=True, verbose_name="Marka")
    model = models.CharField(max_length=100, blank=True, verbose_name="Model")
    serial_no = models.CharField(max_length=100, blank=True, verbose_name="Seri No")
    measure_range = models.CharField(max_length=100, blank=True, verbose_name="Ölçüm Aralığı")
    resolution = models.CharField(max_length=100, blank=True, verbose_name="Çözünürlük")
    unit = models.CharField(max_length=50, blank=True, verbose_name="Birim")
    accuracy = models.CharField(max_length=100, blank=True, verbose_name="Doğruluk")
    uncertainty = models.CharField(max_length=100, blank=True, verbose_name="Belirsizlik")
    acceptance_criteria = models.CharField(max_length=200, blank=True, verbose_name="Kabul Kriteri")
    calibration_method = models.CharField(max_length=200, blank=True, verbose_name="Kalibrasyon Yöntemi")
    standard_device = models.CharField(max_length=200, blank=True, verbose_name="Standart Cihaz")
    standard_id = models.CharField(max_length=100, blank=True, verbose_name="Standart ID")
    owner = models.CharField(max_length=100, blank=True, verbose_name="Sorumlu")
    responsible_email = models.EmailField(blank=True, verbose_name="Sorumlu E-posta")
    is_active = models.BooleanField(default=True, verbose_name="Aktif")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Oluşturulma")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Güncellenme")

    class Meta:
        verbose_name = "Kalibrasyon Varlığı"
        verbose_name_plural = "Kalibrasyon Varlıkları"
        ordering = ['asset_code']

    def __str__(self):
        return f"{self.asset_code} - {self.asset_name}"


class CalibrationRecord(models.Model):
    """Kalibrasyon kayıtları"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    asset = models.ForeignKey(
        CalibrationAsset,
        on_delete=models.CASCADE,
        related_name='calibration_records',
        verbose_name="Cihaz"
    )
    calibration_date = models.DateField(verbose_name="Kalibrasyon Tarihi")
    last_calibration = models.DateField(null=True, blank=True, verbose_name="Son Kalibrasyon")
    next_calibration = models.DateField(null=True, blank=True, verbose_name="Sonraki Kalibrasyon")
    calibrated_by = models.CharField(max_length=100, blank=True, verbose_name="Kalibrasyonu Yapan")
    certificate_no = models.CharField(max_length=100, blank=True, verbose_name="Sertifika No")
    status = models.CharField(
        max_length=20,
        choices=[
            ('pass', 'Başarılı'),
            ('fail', 'Başarısız'),
            ('pending', 'Beklemede'),
        ],
        default='pending',
        verbose_name="Durum"
    )
    notes = models.TextField(blank=True, verbose_name="Notlar")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Oluşturulma")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Güncellenme")

    class Meta:
        verbose_name = "Kalibrasyon Kaydı"
        verbose_name_plural = "Kalibrasyon Kayıtları"
        ordering = ['-calibration_date']

    def __str__(self):
        return f"{self.asset.asset_code} - {self.calibration_date}"