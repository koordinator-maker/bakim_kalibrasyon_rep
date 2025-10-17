from django.contrib import admin
from django.urls import path, include

# Admin site ayarları
admin.site.site_header = "Bakım Kalibrasyon Yönetim"
admin.site.site_title = "Bakım Kalibrasyon"
admin.site.index_title = "Yönetim Paneli"

# Admin düzeltmesini import et
try:
    import core.admin_fix
except ImportError:
    pass

urlpatterns = [
    path('admin/', admin.site.urls),
]