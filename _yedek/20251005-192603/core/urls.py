from django.contrib import admin
from django.urls import path

# Admin modüllerini (maintenance.admin dahil) kesin olarak yükle
admin.autodiscover()

urlpatterns = [
    path('admin/', admin.site.urls),
]