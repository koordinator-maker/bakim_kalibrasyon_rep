# core/urls.py
from django.urls import path
from maintenance.models import Equipment
from maintenance.admin import admin_site
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode

def equipment_list_direct(request, *args, **kwargs):
    ma = admin_site._registry[Equipment]
    view = admin_site.admin_view(ma.changelist_view)
    q = request.GET.copy()
    for k in ("_changelist_filters", "preserved_filters", "p"):
        q.pop(k, None)
    request.GET = q
    request.META["QUERY_STRING"] = q.urlencode()
    resp = view(request, *args, **kwargs)
    try:
        loc = resp.headers.get("Location")
    except Exception:
        loc = None
    if getattr(resp, "status_code", 200) in (301, 302) and loc:
        base = "/admin/maintenance/equipment/_direct/"
        from django.http import HttpResponseRedirect
        if urlsplit(loc).path.endswith(base):
            u = urlsplit(loc)
            qs = [(k,v) for (k,v) in parse_qsl(u.query) if k not in ("_changelist_filters","preserved_filters","p")]
            qs.append(("_noloop","1"))
            return HttpResponseRedirect(urlunsplit((u.scheme,u.netloc,u.path,urlencode(qs),u.fragment)))
    return resp

urlpatterns = [
    path("admin/maintenance/equipment/_direct/", equipment_list_direct, name="equipment_list_direct"),
    # KANONİK YOLU DA AYNI WRAP’E BAĞLA (opsiyonel):
    path("admin/maintenance/equipment/",       equipment_list_direct, name="equipment_list"),
    path("admin/", admin_site.urls),
]
