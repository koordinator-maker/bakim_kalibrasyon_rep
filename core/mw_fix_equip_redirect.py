# -*- coding: utf-8 -*-
# core/mw_fix_equip_redirect.py
from urllib.parse import parse_qsl, urlencode
from django.utils.deprecation import MiddlewareMixin
from django.http import HttpResponseRedirect

CANONICAL = "/admin/maintenance/equipment/"
DIRECT    = "/admin/maintenance/equipment/_direct/"

BLOCK_KEYS = ("_changelist_filters", "preserved_filters", "p")

def _filtered_qs(environ_qs: str) -> str:
    try:
        pairs = parse_qsl(environ_qs or "", keep_blank_values=True)
    except Exception:
        pairs = []
    pairs = [(k, v) for (k, v) in pairs if k not in BLOCK_KEYS]
    qs = urlencode(pairs, doseq=True)
    return ("?" + qs) if qs else ""

class AdminEquipmentRedirectFixMiddleware(MiddlewareMixin):
    """
    /admin/maintenance/equipment/ hedefli TÜM istek/yanıtları güvenli _direct listesine çevirir.
    - process_request: view'e gitmeden önce 302'yle _direct'e yönlendir.
    - process_response: 301/302 Location header'ı kanonik listeyi gösteriyorsa _direct'e çevir.
    """

    def process_request(self, request):
        try:
            path = request.path
        except Exception:
            path = ""
        if path.endswith(CANONICAL):
            qs = _filtered_qs(getattr(request.META, "QUERY_STRING", "") or request.META.get("QUERY_STRING",""))
            return HttpResponseRedirect(DIRECT + qs)

    def process_response(self, request, response):
        # Yanıt 301/302 ise ve hedef kanonik listeyse, _direct'e çevir
        try:
            loc = response["Location"] if hasattr(response, "has_header") and response.has_header("Location") \
                  else (response.headers.get("Location") if hasattr(response, "headers") else None)
        except Exception:
            loc = None

        code = getattr(response, "status_code", 200)
        if code in (301, 302) and loc:
            # Sadece path kısmı ile karşılaştır: çoğu zaman relative Location geliyor
            if str(loc).split("?",1)[0].endswith(CANONICAL):
                qs = ""
                try:
                    # request tarafındaki mevcut QUERY_STRING'i filtreleyip koru
                    qs = _filtered_qs(request.META.get("QUERY_STRING",""))
                except Exception:
                    qs = ""
                try:
                    response["Location"] = DIRECT + qs
                except Exception:
                    pass
        return response
