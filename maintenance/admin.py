from django.contrib import admin
from .models import Equipment

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'serial_number', 'location', 'manufacturer', 'is_active')
    list_filter = ('location', 'is_active')
    search_fields = ('name', 'serial_number')
    
    # EQP-003 testi için 'manufacturer' alanının formda görünür olduğundan emin olunur.
    fieldsets = (
        (None, {
            'fields': ('name', 'serial_number', 'manufacturer', 'purchase_date', 'last_maintenance_date', 'next_maintenance_date', 'location', 'is_active')
        }),
    )
from .models import CalibrationAsset, CalibrationRecord

@admin.register(CalibrationAsset)
class CalibrationAssetAdmin(admin.ModelAdmin):
    list_display = ('asset_code', 'asset_name', 'location', 'brand', 'is_active')
    list_filter = ('is_active', 'location', 'brand')
    search_fields = ('asset_code', 'asset_name', 'serial_no', 'location')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Temel Bilgiler', {
            'fields': ('asset_code', 'asset_name', 'location', 'is_active')
        }),
        ('Cihaz Detayları', {
            'fields': ('brand', 'model', 'serial_no', 'measure_range', 'resolution', 'unit')
        }),
        ('Kalibrasyon Bilgileri', {
            'fields': ('accuracy', 'uncertainty', 'acceptance_criteria', 'calibration_method')
        }),
        ('Standart ve Sorumluluk', {
            'fields': ('standard_device', 'standard_id', 'owner', 'responsible_email')
        }),
        ('Sistem Bilgileri', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(CalibrationRecord)
class CalibrationRecordAdmin(admin.ModelAdmin):
    list_display = ('asset', 'calibration_date', 'status', 'next_calibration', 'calibrated_by')
    list_filter = ('status', 'calibration_date')
    search_fields = ('asset__asset_code', 'asset__asset_name', 'certificate_no', 'calibrated_by')
    date_hierarchy = 'calibration_date'
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Kalibrasyon Bilgileri', {
            'fields': ('asset', 'calibration_date', 'last_calibration', 'next_calibration', 'status')
        }),
        ('Detaylar', {
            'fields': ('calibrated_by', 'certificate_no', 'notes')
        }),
        ('Sistem Bilgileri', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )