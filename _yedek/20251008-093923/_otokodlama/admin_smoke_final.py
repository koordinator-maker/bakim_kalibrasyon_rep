import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.conf import settings
from django.urls import reverse, NoReverseMatch, clear_url_caches, get_resolver
from importlib import import_module, reload
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from maintenance.models import Equipment
from django.contrib.auth import get_user_model
from django.test import Client

# Admin registry'yi yükle ve URL resolver'ı tazeleyip yeniden derle
admin.autodiscover()
clear_url_caches()
reload(import_module(settings.ROOT_URLCONF))

# Çekirdek admin reverse'leri
print("admin:index ->", reverse("admin:index"))
print("admin:login ->", reverse("admin:login"))
try:
    print("admin:app_list(maintenance) ->", reverse("admin:app_list", kwargs={"app_label":"maintenance"}))
except NoReverseMatch as e:
    print("WARN app_list:", e)

# Model bazlı isimleri deneyelim (namespace + app + model + action)
nm_cl  = f"admin:{Equipment._meta.app_label}_{Equipment._meta.model_name}_changelist"
nm_add = f"admin:{Equipment._meta.app_label}_{Equipment._meta.model_name}_add"

# Debug: resolver'daki ilgili isimleri göster
names = sorted(n for n in get_resolver().reverse_dict.keys()
               if isinstance(n, str) and "admin" in n and Equipment._meta.model_name in n)
print("resolver names (sample):", names[:10])

for nm in (nm_cl, nm_add):
    try:
        print(nm, "->", reverse(nm))
    except NoReverseMatch as e:
        print("WARN", nm, "->", e)

# Superuser garanti
User = get_user_model()
u, _ = User.objects.get_or_create(username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True})
u.is_staff = True; u.is_superuser = True; u.set_password("admin123!"); u.save()

# Login + gerçek URL yoluyla duman testi
c = Client()
c.post("/admin/login/?next=/admin/", {
    "username":"admin","password":"admin123!",
    "this_is_the_login_form":1,"next":"/admin/"
}, follow=True)

cl_path  = f"/admin/{Equipment._meta.app_label}/{Equipment._meta.model_name}/"
add_path = f"/admin/{Equipment._meta.app_label}/{Equipment._meta.model_name}/add/"

print("CL  status:", c.get(cl_path).status_code, cl_path)
print("ADD status:", c.get(add_path).status_code, add_path)