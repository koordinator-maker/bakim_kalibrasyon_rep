import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
admin.autodiscover()  # güvenli

from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse, NoReverseMatch
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from maintenance.models import Equipment

# kritik reverse'ler
print("admin:index ->", reverse("admin:index"))
print("admin:login ->", reverse("admin:login"))

# app_list bazı sürümlerde/kurulumlarda isim/ekleme farkı yüzünden reverse edilmeyebilir
try:
    print("admin:app_list(maintenance) ->", reverse("admin:app_list", kwargs={"app_label":"maintenance"}))
except NoReverseMatch as e:
    print("WARN app_list:", e)

# model bazlı reverse (garanti)
nm_cl  = admin_urlname(Equipment._meta, "changelist")
nm_add = admin_urlname(Equipment._meta, "add")
print(nm_cl,  "->", reverse(nm_cl))
print(nm_add, "->", reverse(nm_add))

# superuser garanti
User = get_user_model()
u, _ = User.objects.get_or_create(username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True})
u.is_staff = True; u.is_superuser = True; u.set_password("admin123!"); u.save()

# login + sayfa durumları
c = Client()
c.post("/admin/login/?next=/admin/", {
    "username":"admin","password":"admin123!",
    "this_is_the_login_form":1,"next":"/admin/"
}, follow=True)

print("CL  status:", c.get("/admin/maintenance/equipment/").status_code)
print("ADD status:", c.get("/admin/maintenance/equipment/add/").status_code)