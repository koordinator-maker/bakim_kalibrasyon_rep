# -*- coding: utf-8 -*-
from django.urls import path
from maintenance.admin import admin_site

urlpatterns = [
    path("admin/", admin_site.urls),
]