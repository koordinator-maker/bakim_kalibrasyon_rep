import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.test import Client
c = Client()
r = c.get("/admin/"); print("GET /admin/ ->", r.status_code)  # 302 beklenir

resp = c.post("/admin/login/?next=/admin/", {
    "username":"admin","password":"admin123!",
    "this_is_the_login_form":1,"next":"/admin/"
}, follow=True)
print("login final status:", resp.status_code)

r1 = c.get("/admin/maintenance/equipment/"); print("CL status:", r1.status_code)  # 200
r2 = c.get("/admin/maintenance/equipment/add/"); print("ADD status:", r2.status_code)  # 200