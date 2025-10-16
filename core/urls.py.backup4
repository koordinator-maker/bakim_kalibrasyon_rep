from django.contrib import admin
from django.urls import path, include
from django.shortcuts import redirect

# 🔧 FIX: Admin site özelleştirme
admin.site.site_header = "Bakım Kalibrasyon"
admin.site.site_title = "Admin"
admin.site.index_title = "Yönetim"

# 🔧 FIX: Admin namespace ekle
admin.autodiscover()

urlpatterns = [
    path('', lambda request: redirect('admin:index', permanent=False)),
    path('admin/', admin.site.urls, name='admin'),  # 🔧 name ekle
    path('maintenance/', include('maintenance.urls')),
]