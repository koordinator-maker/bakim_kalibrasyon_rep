# Bu dosya, toplu admin aksiyonları için gereken yardımcı fonksiyonları içerir.
def make_active(modeladmin, request, queryset):
    """Seçili objeleri toplu olarak aktif yapar."""
    queryset.update(is_active=True)
make_active.short_description = "Seçili öğeleri aktif yap"

def make_inactive(modeladmin, request, queryset):
    """Seçili objeleri toplu olarak pasif yapar."""
    queryset.update(is_active=False)
make_inactive.short_description = "Seçili öğeleri pasif yap"
