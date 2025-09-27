# -*- coding: utf-8 -*-
from django.urls import path
from maintenance.models import Equipment
from maintenance.admin import admin_site

# Döngü guard'lı gerçek changelist
def equipment_list_direct(request, *args, **kwargs):
    ma = admin_site._registry[Equipment]
    view = admin_site.admin_view(ma.changelist_view)
    # Güvenli tarafta kalmak için request.GET içini sterilize edelim:
    q = request.GET.copy()
    for k in ("_changelist_filters", "preserved_filters", "p"):
        q.pop(k, None)
    request.GET = q
    request.META["QUERY_STRING"] = q.urlencode()
    return view(request, *args, **kwargs)

urlpatterns = [
    path("admin/maintenance/equipment/_direct/", equipment_list_direct, name="equipment_list_direct"),
    path("admin/", admin_site.urls),
]
