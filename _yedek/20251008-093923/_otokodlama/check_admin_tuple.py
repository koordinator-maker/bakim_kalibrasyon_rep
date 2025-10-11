import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
tpl = admin.site.urls  # (urlpatterns, app_name, namespace)
print("app_name:", tpl[1], "| namespace:", tpl[2])