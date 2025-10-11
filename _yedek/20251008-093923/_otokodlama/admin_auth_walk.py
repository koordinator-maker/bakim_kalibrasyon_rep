import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()
from django.urls import resolve, Resolver404
for p in ["/admin/","/admin/maintenance/equipment/","/admin/maintenance/equipment/add/"]:
    try:
        m = resolve(p)
        print(p, "-> OK:", m.func.__module__)
    except Resolver404:
        print(p, "-> 404 (pattern yok)")