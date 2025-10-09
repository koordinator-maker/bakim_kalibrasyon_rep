import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib import admin
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from maintenance.models import Equipment

# Süper kullanıcı garanti
U = get_user_model()
u, _ = U.objects.get_or_create(
    username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True}
)
u.is_staff = True; u.is_superuser = True; u.set_password("admin123!"); u.save()

# Login + kontroller
c = Client()
c.force_login(u)  # login formuna post atmaya gerek yok, direkt oturum aç
print("admin:index ->", c.get(reverse("admin:index")).status_code)

nm_cl  = admin_urlname(Equipment._meta, "changelist")
nm_add = admin_urlname(Equipment._meta, "add")
cl_url  = reverse(nm_cl)
add_url = reverse(nm_add)

r1 = c.get(cl_url)
r2 = c.get(add_url)
print("CL  status:", r1.status_code, cl_url)
print("ADD status:", r2.status_code, add_url)

# Basit bir içerik işareti (isteğe bağlı)
print("Has 'Equipment' in CL page?:", "Equipment" in r1.content.decode("utf-8", "ignore"))