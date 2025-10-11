from django.contrib import admin
from django.urls import path, include
from django.shortcuts import redirect

urlpatterns = [
    # root URL'ye gidildiğinde /admin/'e yönlendir
    path('', lambda request: redirect('admin/', permanent=False)),
    
    # Standart Django Admin yolu
    path('admin/', admin.site.urls),
    
    # Uygulama URL'leri
    path('maintenance/', include('maintenance.urls')),
]
