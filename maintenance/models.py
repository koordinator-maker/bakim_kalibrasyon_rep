# REV: 1.0 | 2025-09-24 | Hash: 5f179057 | Parça: 1/1
# -*- coding: utf-8 -*-
from __future__ import annotations
from django.db import models

# ----------------------------------------------------------------------
# Ekipman
# ----------------------------------------------------------------------
class Equipment(models.Model):
    DISCIPLINE_CHOICES = (
        ("ELEC", "Elektrik"),
        ("MECH", "Mekanik"),
        ("PNEU", "Pnömatik"),
    )
    code = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=200)
    area = models.CharField(max_length=120, blank=True)
    # Üretici firma alanı eklendi (admin listelerinde kullanılıyor)
    manufacturer = models.CharField("Üretici Firma", max_length=200, blank=True)
    discipline = models.CharField(max_length=4, choices=DISCIPLINE_CHOICES, default="MECH")
    criticality = models.PositiveSmallIntegerField(default=3, help_text="1=En kritik, 5=En az kritik")
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["code"]

    def __str__(self):
        return f"{self.code} - {self.name}"


# ----------------------------------------------------------------------
# (Varsa) Yedek Parça
# ----------------------------------------------------------------------
class SparePart(models.Model):
    name = models.CharField(max_length=150)
    is_critical = models.BooleanField(default=False)
    stock_qty = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    min_qty = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    equipment = models.ForeignKey(Equipment, null=True, blank=True, on_delete=models.SET_NULL)

    def __str__(self):
        return self.name


# ----------------------------------------------------------------------
# KALİBRASYON: Cihaz Kartı
# ----------------------------------------------------------------------
class CalibrationAsset(models.Model):
    equipment = models.ForeignKey(Equipment, on_delete=models.SET_NULL, null=True, blank=True)

    asset_code = models.CharField("Cihaz Kodu", max_length=120, unique=True)
    asset_name = models.CharField("Cihaz Adı", max_length=200)
    location = models.CharField("Lokasyon", max_length=150, blank=True)

    brand = models.CharField("Marka", max_length=120, blank=True)
    model = models.CharField("Model", max_length=120, blank=True)
    serial_no = models.CharField("Seri No", max_length=120, blank=True)

    measure_range = models.CharField("Ölçüm Aralığı", max_length=120, blank=True)
    resolution = models.CharField("Çözünürlük", max_length=120, blank=True)
    unit = models.CharField("Birim", max_length=30, blank=True)

    accuracy = models.CharField("Doğruluk", max_length=120, blank=True)
    uncertainty = models.CharField("Belirsizlik", max_length=120, blank=True)
    acceptance_criteria = models.CharField("Kabul Kriteri", max_length=200, blank=True)

    calibration_method = models.CharField("Yöntem/Prosedür", max_length=200, blank=True)
    standard_device = models.CharField("Referans/Standart Cihaz", max_length=200, blank=True)
    standard_id = models.CharField("Standart Cihaz ID", max_length=120, blank=True)

    owner = models.CharField("Sorumlu", max_length=120, blank=True)
    responsible_email = models.EmailField("Sorumlu E-posta", blank=True)

    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Kalibrasyon Cihazı"
        verbose_name_plural = "Kalibrasyon Cihazları"
        ordering = ["asset_code"]

    def __str__(self):
        return f"{self.asset_code} - {self.asset_name}"


# ----------------------------------------------------------------------
# KALİBRASYON Kayıtları (Geçmiş/Gelecek)
# ----------------------------------------------------------------------
class CalibrationRecord(models.Model):
    asset = models.ForeignKey(CalibrationAsset, on_delete=models.CASCADE, related_name="records")

    last_calibration = models.DateField("Son Kalibrasyon", null=True, blank=True)
    next_calibration = models.DateField("Sonraki Kalibrasyon", null=True, blank=True)

    # Sonuç (OK / UYGUN / UYGUN DEĞİL vb.)
    result = models.CharField("Sonuç", max_length=120, blank=True)
    certificate_no = models.CharField("Sertifika No", max_length=120, blank=True)

    # Toplam sapma (rapordaki birleşik/En büyük sapma) – opsiyonel
    total_deviation = models.DecimalField("Toplam Sapma", max_digits=10, decimal_places=4, null=True, blank=True)

    notes = models.TextField("Notlar", blank=True)

    class Meta:
        ordering = ["-next_calibration", "-id"]

    def __str__(self):
        return f"{self.asset.asset_code} {self.next_calibration or ''}"


# ----------------------------------------------------------------------
# Checklist ve İş Emri
# ----------------------------------------------------------------------
class MaintenanceChecklistItem(models.Model):
    FREQ = (
        ("DAILY", "Günlük"),
        ("WEEKLY", "Haftalık"),
        ("MONTHLY", "Aylık"),
        ("QTR", "3 Aylık"),
        ("YEARLY", "Yıllık"),
    )
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    name = models.CharField(max_length=200)
    is_mandatory = models.BooleanField(default=True)
    frequency = models.CharField(max_length=10, choices=FREQ, default="MONTHLY")

    def __str__(self):
        return f"{self.equipment.code} - {self.name}"


class MaintenanceOrder(models.Model):
    TYPE_CHOICES = (("PLN", "Planlı"), ("PRD", "Kestirimci"), ("BRK", "Arızi"))
    STATUS_CHOICES = (("SCHEDULED", "Planlandı"), ("COMPLETED", "Tamamlandı"), ("OVERDUE", "Gecikmiş"))

    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    order_type = models.CharField(max_length=3, choices=TYPE_CHOICES, default="PLN")
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    technician = models.CharField(max_length=120, blank=True)

    start_date = models.DateField(null=True, blank=True)
    due_date = models.DateField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default="SCHEDULED")

    duration_hours = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    cost_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    class Meta:
        ordering = ["-due_date", "-id"]

    def __str__(self):
        return f"{self.title} ({self.get_order_type_display()})"
