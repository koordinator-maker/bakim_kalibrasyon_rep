# -*- coding: utf-8 -*-
import re, pathlib

root = pathlib.Path(__file__).resolve().parents[1]
adm_path = root / "maintenance" / "admin.py"

s = adm_path.read_text(encoding="utf-8").splitlines()

def has_line(rx):
    return any(re.search(rx, ln) for ln in s)

# A) @admin.register(Equipment, ...) dekoratörünü temizle (sadece satırı kaldır)
out = []
skip_next_blank = False
for ln in s:
    if re.match(r'\s*@\s*admin\.register\(\s*Equipment', ln):
        # dekoratör satırını atla
        skip_next_blank = False
        continue
    # opsiyonel: hemen altındaki boş satırı olduğu gibi bırakabiliriz; zararı yok
    out.append(ln)
s = out

# B) AlreadyRegistered importu ekle
txt = "\n".join(s)
if "from django.contrib.admin.sites import AlreadyRegistered" not in txt:
    inserted = False
    for i, ln in enumerate(s):
        if re.match(r'\s*from\s+django\.contrib\s+import\s+admin\b', ln):
            s.insert(i+1, 'from django.contrib.admin.sites import AlreadyRegistered')
            inserted = True
            break
    if not inserted:
        # yoksa başa ekleyelim (admin importu da garanti edelim)
        if not any(re.match(r'\s*from\s+django\.contrib\s+import\s+admin\b', x) for x in s):
            s.insert(0, 'from django.contrib import admin')
        s.insert(1, 'from django.contrib.admin.sites import AlreadyRegistered')

# C) EquipmentAdmin sınıfına get_preserved_filters ekle (redirect döngüsünü keser)
txt = "\n".join(s)
has_method = "def get_preserved_filters(self, request):" in txt

# Sınıf tanımı satırını bul
class_idx = None
class_rx = re.compile(r'^\s*class\s+EquipmentAdmin\s*\(\s*admin\.ModelAdmin\s*\)\s*:\s*$', re.M)
for i, ln in enumerate(s):
    if class_rx.match(ln):
        class_idx = i
        break

if class_idx is not None and not has_method:
    indent = re.match(r'^(\s*)', s[class_idx]).group(1) + "    "
    method_block = [
        indent + "def get_preserved_filters(self, request):",
        indent + "    # avoid redirect loop originating from preserved_filters",
        indent + '    return ""',
        ""
    ]
    # Sınıf gövdesinin hemen başına enjekte et (docstring varsa üstüne gelmesi sorun değil)
    s[class_idx+1:class_idx+1] = method_block

elif class_idx is None:
    # Sınıf hiç yoksa minimal sınıf ekle
    s += [
        "",
        "class EquipmentAdmin(admin.ModelAdmin):",
        "    def get_preserved_filters(self, request):",
        '        return ""',
        ""
    ]

# D) admin_site ile güvenli register (idempotent)
txt = "\n".join(s)
if not re.search(r'admin_site\.register\(\s*Equipment', txt):
    s += [
        "try:",
        "    admin_site.register(Equipment, EquipmentAdmin)",
        "except AlreadyRegistered:",
        "    pass",
        ""
    ]

adm_path.write_text("\n".join(s), encoding="utf-8")
print("[patch v2] maintenance/admin.py ok")