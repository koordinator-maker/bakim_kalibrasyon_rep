import os, sys, django
from itertools import islice
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.urls import get_resolver
from django.contrib import admin
from maintenance.models import Equipment

res = get_resolver()
names = []
for k in res.reverse_dict.keys():
    if isinstance(k, str) and ("admin" in k or "maintenance" in k):
        names.append(k)

print("~ İlk 50 isim ~")
for n in islice(sorted(set(names)), 50):
    print(n)

# Ayrıca model bazlı isimleri üret ve tersine çevir
from django.contrib.admin.templatetags.admin_urls import admin_urlname
nm_cl = admin_urlname(Equipment._meta, "changelist")
nm_add = admin_urlname(Equipment._meta, "add")
print("nm_cl:", nm_cl)
print("nm_add:", nm_add)

from django.urls import reverse
print("reverse(cl):", reverse(nm_cl))
print("reverse(add):", reverse(nm_add))