# REV: 1.1 | 2025-09-25 | Hash: 45ddb718 | ParÃ§a: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-3PR10E2P
# -*- coding: utf-8 -*-
# core/urls.py
from django.urls import path
from django.views.generic import RedirectView

from maintenance.admin import admin_site
from maintenance.views import calibration_full_table

# <<< BLOK SONU: ID:PY-IMP-3PR10E2P
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-32TCAEFD
urlpatterns = [
    # Ã–zel admin site (/admin/ altÄ±nda)
    path("admin/", admin_site.urls),

    # Kalibrasyon tam tablo gÃ¶rÃ¼nÃ¼mÃ¼
    path("calibration/table/", calibration_full_table, name="calibration-full-table"),

    # KÄ±sa yollar (kolaylÄ±k iÃ§in):
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
# <<< BLOK SONU: ID:PY-HEL-32TCAEFD

