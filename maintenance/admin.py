# REV: 1.1 | 2025-10-01 | Hash: 6b349b1e | Parça: 1/1
# -*- coding: utf-8 -*-
from django.contrib import admin
from .models import Equipment, SparePart, CalibrationAsset, CalibrationRecord, MaintenanceChecklistItem, MaintenanceOrder
from core.admin_utils import make_active, make_inactive

# Admin'de /admin/maintenance/equipment/ sonsuz redirect döngüsünü kırmak için
# SADECE EquipmentAdmin için bir monkeypatch uygulandığı varsayılmaktadır.
# Bu kod bloğu, redirect/middleware fix'lerinin üzerine eklenmelidir.

# ----------------------------------------------------------------------
# Ekipman Yönetimi
# ----------------------------------------------------------------------
@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = (
        'code', 
        'name', 
        'discipline', 
        'area', 
        'manufacturer', # EQP-002: Üretici firma kolonu eklendi.
        'criticality', 
        'is_active'
    )
    list_filter = ('discipline', 'criticality', 'is_active')
    search_fields = ('code', 'name', 'manufacturer')
    actions = [make_active, make_inactive]

    # Model save işlemleri için de monkeypatch gerekiyorsa, 
    # ilgili redirect fix'leri burada tanımlanmalıdır.

@admin.register(SparePart)
class SparePartAdmin(admin.ModelAdmin):
    list_display = ('name', 'equipment', 'stock_qty', 'min_qty', 'is_critical')
    list_filter = ('is_critical',)
    search_fields = ('name', 'equipment__code', 'equipment__name')


@admin.register(MaintenanceChecklistItem)
class MaintenanceChecklistItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'equipment', 'frequency', 'is_mandatory')
    list_filter = ('frequency', 'is_mandatory', 'equipment')
    search_fields = ('name', 'equipment__code')


@admin.register(MaintenanceOrder)
class MaintenanceOrderAdmin(admin.ModelAdmin):
    list_display = ('title', 'equipment', 'order_type', 'status', 'due_date', 'technician')
    list_filter = ('status', 'order_type', 'equipment')
    search_fields = ('title', 'equipment__code', 'technician')
    date_hierarchy = 'due_date'

# ----------------------------------------------------------------------
# Kalibrasyon Varlıkları
# ----------------------------------------------------------------------
class CalibrationRecordInline(admin.TabularInline):
    model = CalibrationRecord
    extra = 0
    fields = ('last_calibration', 'next_calibration', 'result', 'certificate_no', 'notes')


@admin.register(CalibrationAsset)
class CalibrationAssetAdmin(admin.ModelAdmin):
    list_display = (
        'asset_code', 
        'asset_name', 
        'equipment', 
        'location', 
        'serial_no', 
        'owner',
        'is_active'
    )
    list_filter = ('is_active', 'location', 'owner')
    search_fields = ('asset_code', 'asset_name', 'serial_no')
    inlines = [CalibrationRecordInline]
    actions = [make_active, make_inactive]


@admin.register(CalibrationRecord)
class CalibrationRecordAdmin(admin.ModelAdmin):
    list_display = ('asset', 'next_calibration', 'last_calibration', 'result', 'certificate_no')
    list_filter = ('result', 'asset')
    date_hierarchy = 'next_calibration'
    search_fields = ('asset__asset_code', 'certificate_no')
