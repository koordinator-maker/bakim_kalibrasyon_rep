# REV: 1.1 | 2025-09-25 | Hash: cb94ad93 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-1QVHDB8X
# -*- coding: utf-8 -*-
from __future__ import annotations
import os
import json
import traceback
from django.core.management.base import BaseCommand
from django.conf import settings

# <<< BLOK SONU: ID:PY-IMP-1QVHDB8X
# >>> BLOK: COMMAND | Komut | ID:PY-COM-4A13QPRK
class Command(BaseCommand):
    help = "Bootreport teşhis komutu: adım adım çalıştırır, klasörleri oluşturur, ayrıntılı çıktı verir."

    def handle(self, *args, **opts):
        base_dir = str(getattr(settings, "BASE_DIR", os.getcwd()))
        var_dir = os.path.join(base_dir, "var")
        json_path = os.path.join(var_dir, "bootreport.json")
        txt_path  = os.path.join(var_dir, "bootreport.txt")

        self.stdout.write(self.style.NOTICE(f"[1/5] BASE_DIR = {base_dir}"))
        self.stdout.write(self.style.NOTICE(f"[2/5] VAR DIR  = {var_dir} (oluşturulacak)"))

        try:
            os.makedirs(var_dir, exist_ok=True)
            self.stdout.write(self.style.SUCCESS(f"  -> OK: {var_dir}"))
        except Exception as e:
            self.stderr.write(f"  -> ERROR mkdir: {e!r}")
            self.stderr.write("  -> Çıkılıyor.")
            return

        self.stdout.write(self.style.NOTICE("[3/5] safe_write_boot_report() çağrılıyor"))
        try:
            from maintenance.bootreport import safe_write_boot_report
        except Exception as e:
            self.stderr.write(f"IMPORT ERROR: maintenance.bootreport -> {e!r}")
            traceback.print_exc()
            return

        # Debug bayrağı aç
        os.environ["BOOTREPORT_DEBUG"] = "1"

        try:
            safe_write_boot_report()
            self.stdout.write(self.style.SUCCESS("  -> safe_write_boot_report() çağrısı tamamlandı"))
        except Exception as e:
            self.stderr.write(f"RUN ERROR: {e!r}")
            traceback.print_exc()
            return

        self.stdout.write(self.style.NOTICE("[4/5] Dosya var mı kontrol"))
        ok_json = os.path.exists(json_path)
        ok_txt  = os.path.exists(txt_path)
        self.stdout.write(f"  JSON exists: {ok_json}  -> {json_path}")
        self.stdout.write(f"  TXT  exists: {ok_txt}   -> {txt_path}")

        if not (ok_json and ok_txt):
            self.stderr.write("  -> Dosyalar oluşmadı. Bootreport içinde bir istisna yakalanıp yutulmuş olabilir.")
            self.stderr.write("  -> Yukarıda traceback görmediysen BOOTREPORT_DEBUG=1 ile tekrar dene veya dosyayı kontrol et.")
            return

        self.stdout.write(self.style.NOTICE("[5/5] Kısa özet"))
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            py = data.get("python", {}).get("version", "")
            dj = data.get("django", {}).get("version", "")
            root = data.get("project", {}).get("root_urlconf", "")
            apps = len(data.get("apps", {}).get("installed_apps", []))
            urls = len(data.get("urls", []))
            models = len(data.get("models", []))
            sig = data.get("signature", {}).get("short", "")
            self.stdout.write(self.style.SUCCESS(
                f"OK: Python={py.split()[0] if py else '-'} Django={dj} Apps={apps} Urls={urls} Models={models} Sig={sig}"
            ))
        except Exception as e:
            self.stderr.write(f"READ JSON ERROR: {e!r}")
            traceback.print_exc()
# <<< BLOK SONU: ID:PY-COM-4A13QPRK
