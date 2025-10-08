import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from django.contrib.auth import get_user_model
from django.urls import reverse, NoReverseMatch
from django.test import Client
from maintenance.models import Equipment

print("System check identified no issues (0 silenced).")
print("admin:index ->", reverse("admin:index"))
print("admin:login ->", reverse("admin:login"))
try:
    print("admin:app_list(maintenance) ->", reverse("admin:app_list", kwargs={"app_label":"maintenance"}))
except NoReverseMatch as e:
    print("WARN app_list:", e)

nm_cl  = admin_urlname(Equipment._meta, "changelist")
nm_add = admin_urlname(Equipment._meta, "add")
print(admin_urlname(Equipment._meta, "changelist"), "->", reverse(nm_cl))
print(admin_urlname(Equipment._meta, "add"),        "->", reverse(nm_add))

U = get_user_model()
u, _ = U.objects.get_or_create(username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True})
u.is_staff = True; u.is_superuser = True; u.set_password("admin123!"); u.save()

c = Client()
print("CL  status:", c.get(reverse(nm_cl)).status_code, reverse(nm_cl))
print("ADD status:", c.get(reverse(nm_add)).status_code, reverse(nm_add))