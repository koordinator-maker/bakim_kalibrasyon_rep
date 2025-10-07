import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()
from django.test import Client
c = Client()
r = c.get("/admin/")
print("status:", r.status_code)
print((r.content[:800]).decode("utf-8","ignore"))