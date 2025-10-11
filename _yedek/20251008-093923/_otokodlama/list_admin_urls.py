import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.urls import reverse, NoReverseMatch

print("site.name:", getattr(admin.site, "name", None))

# kritik üç reverse:
for name, kwargs in [
    ("admin:index", None),
    ("admin:login", None),
    ("admin:app_list", {"app_label":"maintenance"}),
]:
    try:
        print(name, "->", reverse(name, kwargs=kwargs))
    except NoReverseMatch as e:
        print(name, "-> NoReverseMatch:", e)

# model bazlı reverse'lar
from maintenance.models import Equipment
from django.contrib.admin.templatetags.admin_urls import admin_urlname
nm_cl = admin_urlname(Equipment._meta, "changelist")
nm_add = admin_urlname(Equipment._meta, "add")
for nm in [nm_cl, nm_add]:
    try:
        print(nm, "->", reverse(nm))
    except NoReverseMatch as e:
        print(nm, "-> NoReverseMatch:", e)