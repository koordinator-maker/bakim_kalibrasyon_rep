# REV: 1.1 | Otokodlama Taraf?ndan Devre D??? B?rak?ld?
# Y?nlendirme d?ng?s?ne neden olan ?zel Middleware.
class FixEquipRedirectMiddleware:
    """Art?k kullan?lm?yor. Y?nlendirme d?ng?s?n? k?rmak i?in s?f?rland?."""
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Sadece cevab? oldu?u gibi geri d?nd?r
        response = self.get_response(request)
        return response
