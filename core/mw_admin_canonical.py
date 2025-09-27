# -*- coding: utf-8 -*-
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
from django.http import HttpResponseRedirect

BLOCK_KEYS = ("_changelist_filters", "preserved_filters", "p")

class AdminEquipmentCanonicalRedirectMiddleware:
    """
    /admin/maintenance/equipment/ GET isteklerini, URL resolver'a gitmeden önce
    sterilize query ile /admin/maintenance/equipment/_direct/ adresine 302 yapar.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Sadece kanonik liste yolu ve GET
        if request.method == "GET" and request.path == "/admin/maintenance/equipment/":
            u = urlsplit(request.get_full_path())
            qs = [(k, v) for (k, v) in parse_qsl(u.query, keep_blank_values=True) if k not in BLOCK_KEYS]
            new_qs = urlencode(qs)
            target = urlunsplit((u.scheme, u.netloc, "/admin/maintenance/equipment/_direct/", new_qs, u.fragment))
            return HttpResponseRedirect(target)
        return self.get_response(request)
