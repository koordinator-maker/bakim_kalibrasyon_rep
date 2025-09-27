# -*- coding: utf-8 -*-
import io, re, sys, pathlib

root = pathlib.Path(__file__).resolve().parents[1]
adm_path = root / "maintenance" / "admin.py"

text = adm_path.read_text(encoding="utf-8")

# 1) AlreadyRegistered importunu ekle
if "from django.contrib.admin.sites import AlreadyRegistered" not in text:
    # "from django.contrib import admin" satırının hemen altına ekle
    pat = r'(from\s+django\.contrib\s+import\s+admin[^\n]*\n)'
    if re.search(pat, text):
        text = re.sub(pat, r"\1from django.contrib.admin.sites import AlreadyRegistered\n", text, count=1)
    else:
        text = "from django.contrib import admin\nfrom django.contrib.admin.sites import AlreadyRegistered\n" + text

# 2) EquipmentAdmin sınıfına get_preserved_filters ekle (yoksa)
cls_pat = r'(?ms)^\s*class\s+EquipmentAdmin\s*\(\s*admin\.ModelAdmin\s*\)\s*:\s*(?P<body>.*?)(?=^\s*class\s|\Z)'
m = re.search(cls_pat, text)
if m:
    body = m.group("body")
    if "def get_preserved_filters(" not in body:
        # sınıf gövdesinin başına yöntem ekle
        insert = "    def get_preserved_filters(self, request):\n        # Admin preserved_filters yeniden yönlendirme döngüsünü engelle\n        return \"\"\n\n"
        start, end = m.span("body")
        text = text[:start] + insert + text[start:]
else:
    # Yoksa minimal bir tanım ekleyelim (olası ama pek beklemiyoruz)
    text += "\n\nclass EquipmentAdmin(admin.ModelAdmin):\n    def get_preserved_filters(self, request):\n        return \"\"\n"

# 3) @admin.register(Equipment, ...) dekoratörünü kaldır (çift kayıtı engelle)
text = re.sub(r'(?ms)^\s*@\s*admin\.register\(\s*Equipment[^)]*\)\s*\n', '', text)

# 4) admin_site ile güvenli register (idempotent)
if re.search(r'admin_site\.register\(\s*Equipment', text) is None:
    text += ("\ntry:\n"
             "    admin_site.register(Equipment, EquipmentAdmin)\n"
             "except AlreadyRegistered:\n"
             "    pass\n")

adm_path.write_text(text, encoding="utf-8")
print("[patch] maintenance/admin.py ok")