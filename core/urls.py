# -*- coding: utf-8 -*-
# core/urls.py
from django.urls import path
from django.views.generic import RedirectView

from maintenance.admin import admin_site
from maintenance.views import calibration_full_table

urlpatterns = [
    # Özel admin site (/admin/ altında)
    path("admin/", admin_site.urls),

    # Kalibrasyon tam tablo görünümü
    path("calibration/table/", calibration_full_table, name="calibration-full-table"),

    # Kısa yollar (kolaylık için):
    # /maintenance/dashboard/ -> /admin/maintenance/dashboard/
    path(
        "maintenance/dashboard/",
        RedirectView.as_view(url="/admin/maintenance/dashboard/", permanent=False),
        name="maintenance-dashboard-shortcut",
    ),
    # /admin/maintenance/ -> /admin/maintenance/dashboard/
    path(
        "admin/maintenance/",
        RedirectView.as_view(url="/admin/maintenance/dashboard/", permanent=False),
        name="maintenance-root-redirect",
    ),

    # Ana sayfa -> dashboard
    path("", RedirectView.as_view(url="/admin/maintenance/dashboard/", permanent=False)),
]
