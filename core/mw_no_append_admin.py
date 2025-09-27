# -*- coding: utf-8 -*-
from django.middleware.common import CommonMiddleware

class NoAppendSlashForAdmin(CommonMiddleware):
    """
    Admin altındaki URL'lerde CommonMiddleware'in APPEND_SLASH yönlendirmesini devre dışı bırakır.
    Diğer tüm yollar için standart davranış korunur.
    """
    def process_request(self, request):
        p = request.path
        # admin altına giriyorsa bu middleware append_slash yapmasın
        if p.startswith("/admin/"):
            return None
        # diğer tüm yollar: standart davranış
        return super().process_request(request)
