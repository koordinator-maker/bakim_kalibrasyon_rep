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
    def get_app_list(self, request):
        app_list = super().get_app_list(request)
        for app in app_list:
            for m in app.get("models", []):
                # Model adları Django'nun admin menü sözlüğünde ObjectName olarak gelir
                if m.get("object_name") == "Equipment":
                    m["admin_url"] = "/admin/maintenance/equipment/_direct/"
        return app_list

    site_header = "BakÄ±m Kalibrasyon"
    site_title  = "BakÄ±m Kalibrasyon"
    index_title = "YÃ¶netim"

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
# --- SAFE REDIRECTS AFTER SAVE/DELETE (avoid /equipment/ 302 loop) ---
from urllib.parse import urlsplit
from django.http import HttpResponseRedirect

def _equip_safe_list_url(request):
    return "/admin/maintenance/equipment/_direct/"

def _equip_fix_location(request, resp):
    try:
        loc = resp["Location"] if getattr(resp, "has_header", None) and resp.has_header("Location") else (resp.headers.get("Location") if hasattr(resp, "headers") else None)
    except Exception:
        loc = None
    if getattr(resp, "status_code", 200) in (301, 302) and loc:
        if urlsplit(loc).path.endswith("/admin/maintenance/equipment/"):
            # yalnızca kanonik listeye dönüyorsa güvenli listeye çevir
            try:
                resp["Location"] = _equip_safe_list_url(request)
            except Exception:
                pass
    return resp

def _equip_response_post_save_add(self, request, obj):
    resp = admin.ModelAdmin.response_post_save_add(self, request, obj)
    return _equip_fix_location(request, resp)

def _equip_response_post_save_change(self, request, obj):
    resp = admin.ModelAdmin.response_post_save_change(self, request, obj)
    return _equip_fix_location(request, resp)

def _equip_response_delete(self, request, obj_display, obj_id):
    resp = admin.ModelAdmin.response_delete(self, request, obj_display, obj_id)
    return _equip_fix_location(request, resp)

# monkeypatch uygula
EquipmentAdmin.response_post_save_add    = _equip_response_post_save_add
EquipmentAdmin.response_post_save_change = _equip_response_post_save_change
EquipmentAdmin.response_delete           = _equip_response_delete
# --- END PATCH ---

# ==== BEGIN: EQ-ADMIN HARDENING (redirect to _direct) ====
from urllib.parse import parse_qsl, urlencode
from django.http import HttpResponseRedirect

_EQ_DIRECT = "/admin/maintenance/equipment/_direct/"

def _eq_clean_qs(request):
    qs = ""
    try:
        raw = request.META.get("QUERY_STRING", "") or ""
        pairs = parse_qsl(raw, keep_blank_values=True)
        pairs = [(k, v) for (k, v) in pairs if k not in ("_changelist_filters", "preserved_filters", "p")]
        s = urlencode(pairs, doseq=True)
        qs = ("?" + s) if s else ""
    except Exception:
        qs = ""
    return qs

try:
    _EqAdmin = EquipmentAdmin
except NameError:
    _EqAdmin = None

if _EqAdmin is not None:
    # 1) Kanonik listeye gelen her istek: tek atımlık _direct'e redirect
    _orig_changelist = _EqAdmin.changelist_view
    def _eq_changelist_view(self, request, extra_context=None):
        try:
            p = request.path or ""
        except Exception:
            p = ""
        if p.endswith("/_direct/"):
            return _orig_changelist(self, request, extra_context=extra_context)
        return HttpResponseRedirect(_EQ_DIRECT + _eq_clean_qs(request))
    _EqAdmin.changelist_view = _eq_changelist_view

    # 2) _direct pattern'ini gerçekten ekle (admin URL'lerine)
    def _eq_direct_view(self, request, *args, **kwargs):
        return _orig_changelist(self, request, extra_context=None)
    _EqAdmin._eq_direct_view = _eq_direct_view

    _orig_get_urls = _EqAdmin.get_urls
    def _eq_get_urls(self):
        from django.urls import path
        urls = _orig_get_urls(self)
        my = [ path("_direct/", self.admin_site.admin_view(self._eq_direct_view), name="equipment_list_direct") ]
        return my + urls
    _EqAdmin.get_urls = _eq_get_urls

    # 3) Save/Add/Change/Delete sonra daima _direct'e dön
    def _eq_response_post_save_add(self, request, obj):
        return HttpResponseRedirect(_EQ_DIRECT + _eq_clean_qs(request))
    def _eq_response_post_save_change(self, request, obj):
        return HttpResponseRedirect(_EQ_DIRECT + _eq_clean_qs(request))
    def _eq_response_delete(self, request, obj_display, obj_id):
        return HttpResponseRedirect(_EQ_DIRECT + _eq_clean_qs(request))
    _EqAdmin.response_post_save_add    = _eq_response_post_save_add
    _EqAdmin.response_post_save_change = _eq_response_post_save_change
    _EqAdmin.response_delete           = _eq_response_delete
# ==== END: EQ-ADMIN HARDENING ====
