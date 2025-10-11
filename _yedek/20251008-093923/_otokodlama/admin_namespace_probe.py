import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.urls import reverse
from maintenance.models import Equipment
from django.contrib.admin.templatetags.admin_urls import admin_urlname

print("site.name =", getattr(admin.site, "name", None))
print("admin:index  ->", reverse("admin:index"))
print("admin:login  ->", reverse("admin:login"))
print("admin:app_list(maintenance) ->", reverse("admin:app_list", kwargs={"app_label":"maintenance"}))

nm_cl = admin_urlname(Equipment._meta, "changelist")
nm_add = admin_urlname(Equipment._meta, "add")
print("nm_cl =", nm_cl)
print("nm_add =", nm_add)
print("reverse(changelist) ->", reverse(nm_cl))
print("reverse(add)        ->", reverse(nm_add))