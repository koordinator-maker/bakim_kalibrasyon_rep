# REV: 1.0 | 2025-09-25 | Hash: 0bea51d0 | Parça: 1/1
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Django app kayıt düzeltici:
- INSTALLED_APPS içine 'maintenance.apps.MaintenanceConfig' ekler (yoksa)
- maintenance/__init__.py dosyasını garanti eder
- Güvenli: settings.py için .bak yedeği alır
Kullanım:
  python tools/dj_fix_app.py            # düzelt
  python tools/dj_fix_app.py --dry-run  # sadece raporla
"""

import argparse, io, os, re, sys
ROOT = os.path.dirname(os.path.abspath(__file__))  # tools/
ROOT = os.path.abspath(os.path.join(ROOT, '..'))   # repo kökü

SETTINGS_PATH = os.path.join(ROOT, 'core', 'settings.py')
MAINT_DIR      = os.path.join(ROOT, 'maintenance')
MAINT_INIT     = os.path.join(MAINT_DIR, '__init__.py')

RE_INSTALLED = re.compile(r'INSTALLED_APPS\s*=\s*\[(.*?)\]', re.S)

TARGET_APP_LINE = "'maintenance.apps.MaintenanceConfig',"

def read_text(p):
    with io.open(p, 'r', encoding='utf-8', errors='strict') as f:
        return f.read()

def write_text(p, s, newline='\n'):
    # .py dosyaları LF ile yazılsın
    with io.open(p, 'w', encoding='utf-8', newline=newline) as f:
        f.write(s)

def ensure_maint_init(dry=False):
    os.makedirs(MAINT_DIR, exist_ok=True)
    if not os.path.exists(MAINT_INIT):
        txt = "# maintenance paket başlatıcısı\n"
        if not dry:
            write_text(MAINT_INIT, txt, newline='\n')
        return True
    return False

def has_app(s):
    # INSTALLED_APPS bloğunda maintenance var mı?
    m = RE_INSTALLED.search(s)
    if not m:
        return False, None
    block = m.group(1)
    present = re.search(r"['\"]maintenance(\.apps\.MaintenanceConfig)?['\"]", block) is not None
    return present, m

def insert_app(s, match):
    # match: INSTALLED_APPS bloğu
    start, end = match.span(1)  # sadece içerik dilimini hedefle
    block = s[start:end]
    # Satır başı girintisini yakala
    # Ör: INSTALLED_APPS = [\n    'django.contrib.admin',\n]
    indent_match = re.search(r'\n([ \t]+)[^\n]*$', s[:start])
    indent = indent_match.group(1) if indent_match else '    '
    # Varsa ilk satırdan sonra ekle; yoksa direkt başa
    if block.strip():
        new_block = TARGET_APP_LINE + "\n" + block
    else:
        new_block = TARGET_APP_LINE + "\n"
    # Girinti uygula
    new_block = re.sub(r'(^|\n)(?!$)', r'\1' + indent, new_block)
    # Kapanış köşeli parantez öncesi son satırda trailing virgül kalması Django için sorun değildir.
    return s[:start] + new_block + s[end:]

def fix_settings(dry=False):
    if not os.path.exists(SETTINGS_PATH):
        return False, "settings.py bulunamadı: " + SETTINGS_PATH
    src = read_text(SETTINGS_PATH)
    present, m = has_app(src)
    if present:
        return False, "Zaten INSTALLED_APPS içinde maintenance var."
    if not m:
        return False, "settings.py içinde INSTALLED_APPS bloğu bulunamadı."
    fixed = insert_app(src, m)
    if not dry:
        # yedek
        write_text(SETTINGS_PATH + '.bak', src, newline='\n')
        write_text(SETTINGS_PATH, fixed, newline='\n')
    return True, "INSTALLED_APPS içine eklendi: " + TARGET_APP_LINE

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true', help='Değişiklik yapmadan raporla')
    args = ap.parse_args()

    # 1) maintenance/__init__.py
    created = ensure_maint_init(dry=args.dry_run)
    # 2) settings.py
    changed, msg = fix_settings(dry=args.dry_run)

    print("[dj_fix_app] __init__ {} | settings {}".format(
        "OLUŞTURULDU" if created else "zaten var",
        "DÜZELTİLDİ" if changed else "değiştirilmedi"
    ))
    print("[dj_fix_app]", msg)

if __name__ == '__main__':
    sys.exit(main())
