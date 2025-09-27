# -*- coding: utf-8 -*-
from django.contrib import admin
from django.contrib.admin import AdminSite
from django.contrib.admin.sites import AlreadyRegistered

from .models import (
    Equipment,
    MaintenanceChecklistItem,
    MaintenanceOrder,
    CalibrationAsset,
    CalibrationRecord,
)

class MaintenanceAdminSite(AdminSite):
    site_header = "Bakım Kalibrasyon"
    site_title  = "Bakım Kalibrasyon"
    index_title = "Yönetim"

admin_site = MaintenanceAdminSite(name="maintenance_admin")

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

class EquipmentAdmin(admin.ModelAdmin):
    list_display  = ("code", "name")
    search_fields = ("code", "name")

    def get_preserved_filters(self, request):
        return ""

    def changelist_view(self, request, extra_context=None):
        q = request.GET.copy()
        for k in ("_changelist_filters", "preserved_filters", "p"):
            if k in q:
                q.pop(k)
        request.GET = q
        request.META["QUERY_STRING"] = q.urlencode()
        return super().changelist_view(request, extra_context=extra_context)

try:
    admin_site.register(Equipment, EquipmentAdmin)
except AlreadyRegistered:
    pass