import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.urls import reverse, NoReverseMatch
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from maintenance.models import Equipment

print("Registered in default admin site:", Equipment in admin.site._registry)

name_changelist = admin_urlname(Equipment._meta, "changelist")   # Örn: "admin:maintenance_equipment_changelist"
name_add        = admin_urlname(Equipment._meta, "add")          # Örn: "admin:maintenance_equipment_add"
print("Names ->", name_changelist, ",", name_add)

try:
    # DİKKAT: Burada ekstra "admin:" EKLEMİYORUZ
    print("Reverse CL :", reverse(name_changelist))
    print("Reverse ADD:", reverse(name_add))
except NoReverseMatch as e:
    print("NoReverseMatch:", e)