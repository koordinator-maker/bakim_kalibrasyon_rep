# REV: 1.0 | 2025-09-24 | Hash: c1991529 | Parça: 1/1
# -*- coding: utf-8 -*-
from __future__ import annotations
import json
import os
from django.core.management.base import BaseCommand
from django.conf import settings

class Command(BaseCommand):
    help = "bootreport'i çalıştırır, var/ içine dosyaları yazar ve kısa özet basar."

    def handle(self, *args, **opts):
        base_dir = str(getattr(settings, "BASE_DIR", os.getcwd()))
        var_dir = os.path.join(base_dir, "var")
        json_path = os.path.join(var_dir, "bootreport.json")
        txt_path  = os.path.join(var_dir, "bootreport.txt")

        self.stdout.write(self.style.NOTICE(f"BASE_DIR = {base_dir}"))
        self.stdout.write(self.style.NOTICE(f"VAR DIR  = {var_dir}"))

        try:
            from maintenance.bootreport import safe_write_boot_report
        except Exception as e:
            self.stderr.write(f"IMPORT ERROR: maintenance.bootreport -> {e!r}")
            return

        try:
            safe_write_boot_report()
        except Exception as e:
            self.stderr.write(f"RUN ERROR: safe_write_boot_report() -> {e!r}")
            return

        # Dosyalar var mı?
        ok_json = os.path.exists(json_path)
        ok_txt  = os.path.exists(txt_path)
        self.stdout.write(f"JSON exists: {ok_json}  -> {json_path}")
        self.stdout.write(f"TXT  exists: {ok_txt}   -> {txt_path}")

        # Kısa özet
        if ok_json:
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
                    f"OK: Python={py.split()[0] if py else '-'} Django={dj} "
                    f"Apps={apps} Urls={urls} Models={models} Sig={sig}"
                ))
            except Exception as e:
                self.stderr.write(f"READ JSON ERROR: {e!r}")
