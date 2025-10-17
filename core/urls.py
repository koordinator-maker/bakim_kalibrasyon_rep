from django.contrib import admin
from django.urls import path, include
from django.shortcuts import redirect

# Admin site customization
admin.site.site_header = "Bakım Kalibrasyon Yönetim"
admin.site.site_title = "Admin"
admin.site.index_title = "Yönetim Paneli"

urlpatterns = [
    path('', lambda request: redirect('admin:index')),
    path('admin/', admin.site.urls),
    path('maintenance/', include('maintenance.urls')),
]