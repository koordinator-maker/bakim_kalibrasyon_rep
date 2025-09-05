from django.urls import path
from django.views.generic import RedirectView
from maintenance.admin import admin_site

urlpatterns = [
    path("admin/", admin_site.urls),
    path("", RedirectView.as_view(url="/admin/maintenance/dashboard/", permanent=False)),
]
