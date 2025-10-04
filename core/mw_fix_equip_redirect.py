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
    /admin/maintenance/equipment/ hedefli TÃƒÅ“M istek/yanÃ„Â±tlarÃ„Â± gÃƒÂ¼venli _direct listesine ÃƒÂ§evirir.
    - process_request: view'e gitmeden ÃƒÂ¶nce 302'yle _direct'e yÃƒÂ¶nlendir.
    - process_response: 301/302 Location header'Ã„Â± kanonik listeyi gÃƒÂ¶steriyorsa _direct'e ÃƒÂ§evir.
    """

    def process_request(self, request):
        try:
            path = request.path
        except Exception:
            path = ""
        if path.endswith(CANONICAL):
            qs = _filtered_qs(getattr(request.META, "QUERY_STRING", "") or request.META.get("QUERY_STRING",""))
            
# /add/ yolu admin add view iÃƒÆ’Ã‚Â§in bypass
try:
    path = request.get_full_path() if hasattr(request, "get_full_path") else request.path
except Exception:
    path = request.path
if path.endswith("/add/"):
    return None

# /add/ yolu admin add view iÃƒÂ§in bypass
try:
    path = request.get_full_path() if hasattr(request, "get_full_path") else request.path
except Exception:
    path = request.path
if path.endswith("/add/"):
    return None

# /add/ yolu admin add view iÃ§in bypass
try:
    path = request.get_full_path() if hasattr(request, "get_full_path") else request.path
except Exception:
    path = request.path
if path.endswith("/add/"):
    return None
return HttpResponseRedirect(DIRECT + qs)

    def process_response(self, request, response):
        # YanÃ„Â±t 301/302 ise ve hedef kanonik listeyse, _direct'e ÃƒÂ§evir
        try:
            loc = response["Location"] if hasattr(response, "has_header") and response.has_header("Location") \
                  else (response.headers.get("Location") if hasattr(response, "headers") else None)
        except Exception:
            loc = None

        code = getattr(response, "status_code", 200)
        if code in (301, 302) and loc:
            # Sadece path kÃ„Â±smÃ„Â± ile karÃ…Å¸Ã„Â±laÃ…Å¸tÃ„Â±r: ÃƒÂ§oÃ„Å¸u zaman relative Location geliyor
            if str(loc).split("?",1)[0].endswith(CANONICAL):
                qs = ""
                try:
                    # request tarafÃ„Â±ndaki mevcut QUERY_STRING'i filtreleyip koru
                    qs = _filtered_qs(request.META.get("QUERY_STRING",""))
                except Exception:
                    qs = ""
                try:
                    response["Location"] = DIRECT + qs
                except Exception:
                    pass
        return response
