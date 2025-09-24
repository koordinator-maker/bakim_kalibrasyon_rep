# REV: 1.0 | 2025-09-24 | Hash: c6444739 | Parça: 1/1
# -*- coding: utf-8 -*-
from __future__ import annotations
import os
from typing import Dict, Any, List, Tuple
from django.core.management.base import BaseCommand, CommandError
from maintenance.models import CalibrationAsset, CalibrationRecord, Equipment

# Bu komut, .xls/.xlsx dosyasındaki sütunları makul başlıklarla eşleyip
# CalibrationAsset + (opsiyonel) CalibrationRecord oluşturur.
# Örnek kullanım:
#   python manage.py import_calibration_excel --file "C:\path\Kalibrasyon.xlsx" --sheet "Sayfa1"
#
# Gerekli kütüphaneler:
#   pip install pandas openpyxl xlrd==1.2.0
#
# Notlar:
# - .xls için xlrd 1.2.0 gerekir; .xlsx için openpyxl yeterli.
# - Başlık eşlemeleri esnek (Türkçe varyasyonlar desteklenir).

HEADER_MAP = {
    # Cihaz Kartı alanları
    "asset_code": ["cihaz kodu", "kod", "asset code", "code"],
    "asset_name": ["cihaz adı", "ad", "asset name", "name"],
    "location": ["lokasyon", "konum", "location"],
    "brand": ["marka", "brand"],
    "model": ["model", "modeli"],
    "serial_no": ["seri no", "seri no.", "serial", "serial no", "sn"],
    "measure_range": ["ölçüm aralığı", "aralık", "range", "measure range"],
    "resolution": ["çözünürlük", "resolution"],
    "unit": ["birim", "unit"],
    "accuracy": ["doğruluk", "accuracy"],
    "uncertainty": ["belirsizlik", "uncertainty"],
    "acceptance_criteria": ["kabul kriteri", "accept", "acceptance criteria"],
    "calibration_method": ["yöntem", "prosedür", "method", "procedure"],
    "standard_device": ["referans", "standart cihaz", "standard device"],
    "standard_id": ["standart id", "standard id"],
    "owner": ["sorumlu", "owner"],
    "responsible_email": ["e-posta", "email", "mail"],
    # İlişkilendirme
    "equipment_code": ["ekipman kodu", "equipment code", "equipment"],
    # Kalibrasyon kayıtları (opsiyonel)
    "last_calibration": ["son kalibrasyon", "last calibration", "last_cal"],
    "next_calibration": ["sonraki kalibrasyon", "next calibration", "next_cal"],
    "result": ["sonuç", "result"],
    "certificate_no": ["sertifika no", "certificate", "certificate no"],
    "notes": ["not", "notlar", "notes"],
}

DATE_COLS = {"last_calibration", "next_calibration"}

def normalize(s: str) -> str:
    return (s or "").strip().lower()

def find_col(df_cols: List[str], aliases: List[str]) -> str | None:
    al = set(normalize(x) for x in aliases)
    for col in df_cols:
        if normalize(col) in al:
            return col
    # gevşek arama
    for col in df_cols:
        c = normalize(col)
        if any(a in c for a in al):
            return col
    return None

class Command(BaseCommand):
    help = "Excel'den kalibrasyon cihaz ve kayıtlarını içe aktarır."

    def add_arguments(self, parser):
        parser.add_argument("--file", required=True, help="XLS/XLSX dosya yolu")
        parser.add_argument("--sheet", default=None, help="Sayfa adı veya index")
        parser.add_argument("--dry", action="store_true", help="Sadece say, kaydetme")
        parser.add_argument("--default-owner", default="", help="Boşsa kullanılacak sorumlu adı")
        parser.add_argument("--default-email", default="", help="Boşsa kullanılacak sorumlu e-posta")
        parser.add_argument("--create-equipment", action="store_true", help="Ekipman yoksa otomatik oluştur")

    def handle(self, *args, **opts):
        path = opts["file"]
        sheet = opts["sheet"]
        dry = bool(opts["dry"])
        default_owner = opts["default_owner"]
        default_email = opts["default_email"]
        create_eq = bool(opts["create_equipment"])

        if not os.path.exists(path):
            raise CommandError(f"Dosya bulunamadı: {path}")

        # pandas + engine otomatik seçim
        try:
            import pandas as pd  # type: ignore
        except Exception as e:
            raise CommandError("pandas gerekli. Kurulum: pip install pandas openpyxl xlrd==1.2.0") from e

        try:
            if sheet is None:
                df = pd.read_excel(path)  # varsayılan ilk sayfa
            else:
                df = pd.read_excel(path, sheet_name=sheet)
        except Exception as e:
            raise CommandError(f"Excel okunamadı: {e}") from e

        if df.empty:
            self.stdout.write(self.style.WARNING("Dosya boş."))
            return

        cols = list(df.columns)
        self.stdout.write(f"Sütunlar: {cols}")

        # Başlık eşlemeleri
        colmap: Dict[str, str] = {}
        for key, aliases in HEADER_MAP.items():
            col = find_col(cols, aliases)
            if col:
                colmap[key] = col

        required_for_asset = {"asset_code", "asset_name"}
        missing = [k for k in required_for_asset if k not in colmap]
        if missing:
            raise CommandError(f"Gerekli başlık(lar) yok: {missing}. Eşleşenler: {colmap}")

        # Tarih kolonlarını pandas datetime'a çevir
        for k in DATE_COLS:
            if k in colmap:
                try:
                    df[colmap[k]] = pd.to_datetime(df[colmap[k]], errors="coerce").dt.date
                except Exception:
                    pass

        created_assets = 0
        updated_assets = 0
        created_records = 0

        for _, row in df.iterrows():
            data = {k: (row[colmap[k]] if k in colmap else None) for k in HEADER_MAP.keys()}

            # Equipment ilişkisi (opsiyonel)
            eq = None
            eq_code = (data.get("equipment_code") or "") if data.get("equipment_code") is not None else ""
            eq_code = str(eq_code).strip()
            if eq_code:
                eq = Equipment.objects.filter(code=eq_code).first()
                if not eq and create_eq:
                    eq = Equipment.objects.create(code=eq_code, name=eq_code)
            # Asset upsert
            code = str(data["asset_code"]).strip()
            defaults = {
                "asset_name": str(data["asset_name"]).strip(),
                "location": str(data.get("location") or "").strip(),
                "brand": str(data.get("brand") or "").strip(),
                "model": str(data.get("model") or "").strip(),
                "serial_no": str(data.get("serial_no") or "").strip(),
                "measure_range": str(data.get("measure_range") or "").strip(),
                "resolution": str(data.get("resolution") or "").strip(),
                "unit": str(data.get("unit") or "").strip(),
                "accuracy": str(data.get("accuracy") or "").strip(),
                "uncertainty": str(data.get("uncertainty") or "").strip(),
                "acceptance_criteria": str(data.get("acceptance_criteria") or "").strip(),
                "calibration_method": str(data.get("calibration_method") or "").strip(),
                "standard_device": str(data.get("standard_device") or "").strip(),
                "standard_id": str(data.get("standard_id") or "").strip(),
                "owner": str(data.get("owner") or default_owner).strip(),
                "responsible_email": str(data.get("responsible_email") or default_email).strip(),
                "equipment": eq,
                "is_active": True,
            }

            if dry:
                # sadece sayım
                pass
            else:
                asset, created = CalibrationAsset.objects.update_or_create(
                    asset_code=code, defaults=defaults
                )
                if created:
                    created_assets += 1
                else:
                    updated_assets += 1

                # Kalibrasyon kaydı (varsa tarihlerden biri doluysa)
                last_cal = data.get("last_calibration")
                next_cal = data.get("next_calibration")
                result = str(data.get("result") or "").strip()
                cert = str(data.get("certificate_no") or "").strip()
                notes = str(data.get("notes") or "").strip()

                if last_cal or next_cal or result or cert or notes:
                    CalibrationRecord.objects.create(
                        asset=asset,
                        last_calibration=last_cal if last_cal and str(last_cal) != "NaT" else None,
                        next_calibration=next_cal if next_cal and str(next_cal) != "NaT" else None,
                        result=result,
                        certificate_no=cert,
                        notes=notes,
                    )
                    created_records += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Tamam: assets(created={created_assets}, updated={updated_assets}), records(created={created_records})"
            )
        )
