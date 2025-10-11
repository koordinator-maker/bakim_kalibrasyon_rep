import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.urls import reverse, NoReverseMatch
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from maintenance.models import Equipment

print("Registered in default admin site:", Equipment in admin.site._registry)

name_changelist = admin_urlname(Equipment._meta, "changelist")   # ör: "maintenance_equipment_changelist"
name_add        = admin_urlname(Equipment._meta, "add")          # ör: "maintenance_equipment_add"
print("Names ->", name_changelist, ",", name_add)

try:
    print("Reverse CL :", reverse(f"admin:{name_changelist}"))
    print("Reverse ADD:", reverse(f"admin:{name_add}"))
except NoReverseMatch as e:
    print("NoReverseMatch:", e)