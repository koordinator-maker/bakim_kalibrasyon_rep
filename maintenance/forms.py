# REV: 1.0 | 2025-09-24 | Hash: cd2196d0 | Parça: 1/1
# -*- coding: utf-8 -*-
from __future__ import annotations
from django import forms
from .models import MaintenanceChecklistItem

class MaintenanceChecklistItemForm(forms.ModelForm):
    class Meta:
        model = MaintenanceChecklistItem
        fields = [
            "department",        # Bulunduğu Bölüm
            "machine_no",        # Makine No
            "machine_name",      # Makine Adı
            "manufacturer",      # Üretici Firma
            "frequency",         # Bakım / Kontrol Periyodu (dropdown)
            "name",              # Bakım / Kontrol Tanımı (kısa başlık)
            "description",       # Açıklama (opsiyonel, uzun)
            "equipment",         # (İsteğe bağlı) mevcut makine ile bağla
            "is_mandatory",      # Zorunlu işaretle
        ]
        widgets = {
            "department": forms.TextInput(attrs={"placeholder": "Örn: Pres Atölyesi"}),
            "machine_no": forms.TextInput(attrs={"placeholder": "Örn: MC-001"}),
            "machine_name": forms.TextInput(attrs={"placeholder": "Örn: Hat 1 Pres Makinesi"}),
            "manufacturer": forms.TextInput(attrs={"placeholder": "Örn: ABC Makina"}),
            "name": forms.TextInput(attrs={"placeholder": "Kontrol/Bakım adını giriniz"}),
            "description": forms.Textarea(attrs={"rows": 3, "placeholder": "İş adımının detaylı tanımı"}),
        }
        help_texts = {
            "frequency": "Plan üretimi için güvenli kodlarla kullanılacak periyot.",
            "equipment": "İstersen mevcut bir makineyi seçebilirsin; seçilmezse yukarıdaki bilgilerle yeni kayıt mantığına temel oluşturur.",
            "is_mandatory": "İş emrinde mutlaka yapılması gereken kritik bir adım ise işaretleyin.",
        }
