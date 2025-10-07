import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.test import Client

c = Client()

# 1) login sayfasına yönlendirme var mı?
r = c.get("/admin/")
print("GET /admin/ ->", r.status_code)  # 302 beklenir (login'e)

# 2) admin kullanıcısı ile giriş
resp = c.post("/admin/login/?next=/admin/", {
    "username":"admin", "password":"admin123!",
    "this_is_the_login_form":1, "next":"/admin/"
}, follow=True)
print("login final status:", resp.status_code)

# 3) artık changelist/add kaç dönüyor?
r1 = c.get("/admin/maintenance/equipment/")
r2 = c.get("/admin/maintenance/equipment/add/")
print("CL status:", r1.status_code)   # 200 beklenir
print("ADD status:", r2.status_code)  # 200 beklenir