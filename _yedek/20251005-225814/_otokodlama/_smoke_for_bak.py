import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib.auth import get_user_model
from django.test import Client
from maintenance.models import Equipment
from django.contrib.admin.templatetags import admin_urls
from django.urls import reverse

U = get_user_model()
u, _ = U.objects.get_or_create(username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True})
u.is_staff=True; u.is_superuser=True; u.set_password("admin123!"); u.save()

c = Client()
# login sayfasına gidip giriş yap
c.get("/admin/")
c.post("/admin/login/?next=/admin/", {
    "username":"admin","password":"admin123!",
    "this_is_the_login_form":1,"next":"/admin/"
}, follow=True)

cl  = reverse(admin_urls.admin_urlname(Equipment._meta, "changelist"))
add = reverse(admin_urls.admin_urlname(Equipment._meta, "add"))

ok = (c.get(reverse("admin:index")).status_code == 200
      and c.get(cl).status_code == 200
      and c.get(add).status_code == 200)
print("OK" if ok else "FAIL")