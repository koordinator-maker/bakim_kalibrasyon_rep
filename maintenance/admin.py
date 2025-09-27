# -*- coding: utf-8 -*-
from django.contrib import admin
from django.contrib.admin import AdminSite

from .models import (
    Equipment,
    MaintenanceChecklistItem,
    MaintenanceOrder,
    CalibrationAsset,
    CalibrationRecord,
)

class MaintenanceAdminSite(AdminSite):
    site_header = "BakÄ±m Kalibrasyon"
    site_title  = "BakÄ±m Kalibrasyon"
    index_title = "YÃ¶netim"

admin_site = MaintenanceAdminSite(name="maintenance_admin")

@admin.register(Equipment, site=admin_site)
class EquipmentAdmin(admin.ModelAdmin):
    list_display  = ("code", "name")
    search_fields = ("code", "name")
    list_filter   = ()

@admin.register(MaintenanceChecklistItem, site=admin_site)
class MaintenanceChecklistItemAdmin(admin.ModelAdmin):
    list_display  = ("equipment", "name", "frequency", "is_mandatory")
    list_filter   = ("frequency", "is_mandatory")
    search_fields = ("equipment__code", "equipment__name", "name")

@admin.register(MaintenanceOrder, site=admin_site)
class MaintenanceOrderAdmin(admin.ModelAdmin):
    list_display  = ("title", "equipment", "order_type", "status", "due_date", "cost_total")
    list_filter   = ("order_type", "status")
    search_fields = ("title", "equipment__code", "equipment__name")

@admin.register(CalibrationAsset, site=admin_site)
class CalibrationAssetAdmin(admin.ModelAdmin):
    list_display  = ("asset_code", "asset_name", "location", "brand", "model", "serial_no", "equipment")
    search_fields = ("asset_code", "asset_name", "brand", "model", "serial_no")
    list_filter   = ("brand",)

@admin.register(CalibrationRecord, site=admin_site)
class CalibrationRecordAdmin(admin.ModelAdmin):
    list_display  = ("asset", "last_calibration", "next_calibration", "result", "certificate_no", "total_deviation")
    list_filter   = ("result", "next_calibration")
    search_fields = ("asset__asset_code", "asset__asset_name", "certificate_no")
# maintenance/admin.py
from django.contrib import admin
from .models import Equipment

@admin.register(Equipment, site=admin_site)
class EquipmentAdmin(admin.ModelAdmin):
    def changelist_view(self, request, extra_context=None):
        resp = super().changelist_view(request, extra_context)
        try:
            loc = resp.headers.get('Location')
        except Exception:
            loc = None
        print("[DBG] changelist_view status=", getattr(resp, 'status_code', None), "Location=", loc)
        return resp
