from django.contrib import admin
from maintenance.models import Equipment, MaintenanceItem, MaintenanceOrder, CalibrationAsset, CalibrationRecord
from django.contrib.admin import AdminSite
from django.urls import path

# En basit admin sitesini kullan
class MaintenanceAdminSite(AdminSite):
    site_header = "Bak?m & Kalibrasyon Y?netimi"
    site_title = "Bak?m Kalibrasyon"
    index_title = "Anasayfa"

admin_site = MaintenanceAdminSite(name='maintenance_admin')


@admin.register(Equipment, site=admin_site)
class EquipmentAdmin(admin.ModelAdmin):
    # Bu listenin d?zg?n ?al??mas? i?in list_display'i en basit haliyle tutuyoruz
    list_display = ("code", "name", "discipline", "criticality", "is_active")
    list_filter = ("discipline", "criticality", "is_active")
    search_fields = ("code", "name")
    list_editable = ("is_active",)

@admin.register(MaintenanceItem, site=admin_site)
class MaintenanceItemAdmin(admin.ModelAdmin):
    list_display = ("equipment", "name", "frequency", "is_mandatory")
    list_filter = ("frequency", "is_mandatory")
    search_fields = ("equipment__code", "name")

@admin.register(MaintenanceOrder, site=admin_site)
class MaintenanceOrderAdmin(admin.ModelAdmin):
    list_display = ("title", "equipment", "due_date", "status", "order_type")
    list_filter = ("status", "order_type", "equipment")
    search_fields = ("title", "equipment__code")
    readonly_fields = ("completed_at",)

@admin.register(CalibrationAsset, site=admin_site)
class CalibrationAssetAdmin(admin.ModelAdmin):
    list_display = ("asset_code", "asset_name", "location", "brand")
    search_fields = ("asset_code", "asset_name")

@admin.register(CalibrationRecord, site=admin_site)
class CalibrationRecordAdmin(admin.ModelAdmin):
    list_display = ("asset", "next_calibration", "result", "certificate_no")
    list_filter = ("result", "asset")
    date_hierarchy = "next_calibration"
