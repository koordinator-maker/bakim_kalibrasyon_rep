import os, sys, django

# --- PROJE KÖKÜNÜ sys.path'E EKLE ---
HERE = os.path.abspath(os.path.dirname(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()

from django.db import transaction
from maintenance.models import Equipment

MAX_LEN = 120
SUFFIX_DUP = "__DUP__{id}"
SUFFIX_EMPTY = "__EMPTY__{id}"

def safe_unique_value(original: str, suffix: str) -> str:
    room = MAX_LEN - len(suffix)
    base = (original or "")[:room] if room > 0 else ""
    return (base + suffix)[:MAX_LEN]

# 1) Duplikeleri grupla (case-insensitive). Boş/whitespace -> özel anahtar.
by_norm = {}
for e in Equipment.objects.all().order_by("id"):
    raw = e.serial_number
    s = (raw or "")
    norm = s.strip().lower()
    key = norm if norm != "" else "__EMPTY__"
    by_norm.setdefault(key, []).append((e.id, s))

dupe_groups = {k:v for k,v in by_norm.items() if len(v) > 1}
print("Duplike grup sayısı:", len(dupe_groups))

changed = 0
with transaction.atomic():
    for key, rows in dupe_groups.items():
        keeper_id, keeper_val = rows[0]  # ilk kaydı koru
        for (pk, val) in rows[1:]:
            if key == "__EMPTY__":
                new_val = safe_unique_value("", SUFFIX_EMPTY.format(id=pk))
            else:
                new_val = safe_unique_value(val, SUFFIX_DUP.format(id=pk))
            # ekstra güvenlik: yine çakışırsa hafif varyasyon
            q = Equipment.objects.filter(serial_number=new_val).exclude(pk=pk)
            if q.exists():
                new_val = safe_unique_value(val, (SUFFIX_DUP.format(id=pk) + "_X"))
            Equipment.objects.filter(pk=pk).update(serial_number=new_val)
            changed += 1

print("Güncellenen kayıt:", changed)