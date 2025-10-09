import os, sys, django
ROOT = os.path.abspath(".")
if ROOT not in sys.path: sys.path.insert(0, ROOT)
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.db.models import Count
from maintenance.models import Equipment

dupes = (Equipment.objects
         .values("serial_number")
         .annotate(c=Count("id"))
         .filter(c__gt=1))
print("Kalan duplike sayısı:", dupes.count())
print(list(dupes[:20]))