import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.contrib.auth import get_user_model
from django.test import Client
from maintenance.models import Equipment

# superuser garanti
U = get_user_model()
u, _ = U.objects.get_or_create(username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True})
u.is_staff = True; u.is_superuser = True; u.set_password("admin123!"); u.save()

c = Client()
print("GET /admin/ ->", c.get("/admin/").status_code)
c.post("/admin/login/?next=/admin/", {
    "username":"admin","password":"admin123!",
    "this_is_the_login_form":1,"next":"/admin/"
}, follow=True)

cl = f"/admin/{Equipment._meta.app_label}/{Equipment._meta.model_name}/"
ad = f"/admin/{Equipment._meta.app_label}/{Equipment._meta.model_name}/add/"
print("CL:", c.get(cl).status_code, cl)
print("AD:", c.get(ad).status_code, ad)