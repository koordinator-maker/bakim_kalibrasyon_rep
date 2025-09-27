# -*- coding: utf-8 -*-
from django.urls import path
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
from django.http import HttpResponseRedirect

from maintenance.models import Equipment
from maintenance.admin import admin_site

BLOCK_KEYS = ("_changelist_filters", "preserved_filters", "p")
CANONICAL_PATH = "/admin/maintenance/equipment/"
DIRECT_PATH    = "/admin/maintenance/equipment/_direct/"

def _sanitize_qs_str(qs_str: str) -> str:
    return urlencode([(k, v) for (k, v) in parse_qsl(qs_str, keep_blank_values=True)
                      if k not in BLOCK_KEYS])

def _get_location(resp):
    # Django sürümünden bağımsız güvenli Location okuma
    try:
        if hasattr(resp, "has_header") and resp.has_header("Location"):
            return resp["Location"]
        # Django 3.2+ headers dict
        if hasattr(resp, "headers"):
            return resp.headers.get("Location")
    except Exception:
        pass
    return None

# Döngü guard'lı gerçek changelist (KANONİK ve _direct burayı çağırır)
def equipment_list_direct(request, *args, **kwargs):
    ma = admin_site._registry[Equipment]
    view = admin_site.admin_view(ma.changelist_view)

    # 1) Giriş query'sini sterilize et
    q = request.GET.copy()
    for k in BLOCK_KEYS:
        q.pop(k, None)
    request.GET = q
    request.META["QUERY_STRING"] = q.urlencode()

    # 2) Asıl admin view'i çağır
    resp = view(request, *args, **kwargs)

    # 3) Eğer 3xx geldiyse ve şu an KANONİK path'teysek, hedefi zorla _direct yap
    if getattr(resp, "status_code", 200) in (301, 302):
        # _direct'teysek tekrar _direct'e göndermeyelim (sonsuz 302 olmasın)
        if request.path != DIRECT_PATH:
            loc = _get_location(resp)
            # loc varsa onun query'sini, yoksa mevcut request'in query'sini kullan
            qs_str = urlsplit(loc).query if loc else request.META.get("QUERY_STRING", "")
            new_qs = _sanitize_qs_str(qs_str)
            new_loc = urlunsplit(("", "", DIRECT_PATH, new_qs, ""))
            return HttpResponseRedirect(new_loc)

    return resp

urlpatterns = [
    path("admin/maintenance/equipment/",         equipment_list_direct, name="equipment_list"),
    path("admin/maintenance/equipment/_direct/", equipment_list_direct, name="equipment_list_direct"),
    path("admin/", admin_site.urls),
]
