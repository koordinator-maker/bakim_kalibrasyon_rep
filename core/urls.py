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

def equipment_list_direct(request, *args, **kwargs):
    ma = admin_site._registry[Equipment]
    view = admin_site.admin_view(ma.changelist_view)
    q = request.GET.copy()
    for k in ("_changelist_filters", "preserved_filters", "p"):
        q.pop(k, None)
    request.GET = q
    request.META["QUERY_STRING"] = q.urlencode()
    return view(request, *args, **kwargs)

def equipment_list_canonical_redirect(request, *args, **kwargs):
    # Gelen query'i temizle, _direct'e tek atımlık 302 ile gönder
    BLOCK_KEYS = ("_changelist_filters", "preserved_filters", "p")
    try:
        raw_q = request.META.get("QUERY_STRING","")
    except Exception:
        raw_q = ""
    qs = urlencode([(k, v) for (k, v) in parse_qsl(raw_q, keep_blank_values=True) if k not in BLOCK_KEYS])
    return HttpResponseRedirect(urlunsplit(("", "", "/admin/maintenance/equipment/_direct/", qs, "")))
def equipment_canon_redirect(request, *args, **kwargs):
    qs = request.META.get("QUERY_STRING","")
    qs = ("?" + qs) if qs else ""
    return HttpResponseRedirect("/admin/maintenance/equipment/_direct/" + qs)
urlpatterns = [ path("admin/maintenance/equipment/", equipment_canon_redirect),
    path("admin/maintenance/equipment/",         equipment_list_canonical_redirect, name="equipment_list"),
    path("admin/maintenance/equipment/_direct/", equipment_list_direct, name="equipment_list_direct"),
    path("admin/", admin_site.urls),
]

def equipment_list_canonical_redirect(request, *args, **kwargs):
    # Gelen query'i temizle, _direct'e tek atımlık 302 ile gönder
    BLOCK_KEYS = ("_changelist_filters", "preserved_filters", "p")
    try:
        raw_q = request.META.get("QUERY_STRING","")
    except Exception:
        raw_q = ""
    qs = urlencode([(k, v) for (k, v) in parse_qsl(raw_q, keep_blank_values=True) if k not in BLOCK_KEYS])
    return HttpResponseRedirect(urlunsplit(("", "", "/admin/maintenance/equipment/_direct/", qs, "")))
def equipment_canon_redirect(request, *args, **kwargs):
    qs = request.META.get("QUERY_STRING","")
    qs = ("?" + qs) if qs else ""
    return HttpResponseRedirect("/admin/maintenance/equipment/_direct/" + qs)
urlpatterns = [ path("admin/maintenance/equipment/", equipment_canon_redirect),
    path("admin/maintenance/equipment/",         equipment_list_canonical_redirect, name="equipment_list"),
    path("admin/maintenance/equipment/_direct/", equipment_list_direct, name="equipment_list_direct"),
    path("admin/", admin_site.urls),
]




