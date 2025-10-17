from django.contrib import admin
from django.urls import path
from maintenance.views import dashboard_view

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
    # Dashboard URL'i ÖNCE olmalı (önemli!)
    path('admin/maintenance/dashboard/', dashboard_view, name='maintenance_dashboard'),
    
    # Admin URL'i SONRA
    path('admin/', admin.site.urls),
]