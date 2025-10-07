from django.db import transaction
from maintenance.models import Equipment

dupe_ids = []
seen = set()

qs = Equipment.objects.all().order_by('id')
for e in qs:
    sn = (e.serial_number or '').strip()
    if not sn:
        continue
    key = sn.lower()
    if key in seen:
        dupe_ids.append(e.id)
    else:
        seen.add(key)

with transaction.atomic():
    for pk in dupe_ids:
        Equipment.objects.filter(pk=pk).update(serial_number=None)

print("Deduped:", len(dupe_ids), "records set to NULL")