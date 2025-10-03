from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/app_list/<str:app_label>/', admin.site.admin_view(admin.site.app_index), name='app_list'),
    path('admin/', admin.site.urls),
    path('maintenance/', include('maintenance.urls')),
]


