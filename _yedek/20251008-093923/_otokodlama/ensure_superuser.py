import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
u, _ = User.objects.get_or_create(username="admin",
    defaults={"email":"admin@example.com","is_staff":True,"is_superuser":True})
u.is_staff = True; u.is_superuser = True
u.set_password("admin123!")
u.save()
print("ok ->", u.username, u.is_superuser, u.is_staff)