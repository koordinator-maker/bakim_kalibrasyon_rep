# REV: 1.1 | 2025-09-25 | Hash: 5e286802 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-78PPMS41
# -*- coding: utf-8 -*-
from __future__ import annotations
# <<< BLOK SONU: ID:PY-IMP-78PPMS41
# >>> BLOK: COMMAND | Komut | ID:PY-COM-WKWJA9S0
from typing import List, Dict, Any, Tuple
from datetime import date, timedelta

from django.core.management.base import BaseCommand
from django.core.mail import EmailMultiAlternatives, get_connection
from django.template.loader import render_to_string
from django.conf import settings
from django.db.models import Max

from maintenance.models import CalibrationAsset, CalibrationRecord

# Not: Bu komut, mevcut şemayı kullanır:
# CalibrationAsset(... owner, responsible_email, is_active ...) + CalibrationRecord(last_calibration, next_calibration, result, ...)
# Mantık: "önümüzdeki X gün" içinde next_calibration tarihi gelen (veya bugün/geçmiş) kayıtları listeler.
# Eğer bir asset için birden çok kayıt varsa, en yeni "next_calibration" (veya yoksa en son "last_calibration") esas alınır.

def _today() -> date:
    # settings.USE_TZ önemli değil; burada sadece tarih bazında çalışıyoruz.
    return date.today()

def _select_latest_record_map() -> Dict[int, CalibrationRecord]:
    """
    Her asset için en güncel CalibrationRecord'u seçer.
    Öncelik: en büyük next_calibration; eşit/yoksa id'ye göre son oluşturulan.
    """
    latest_for_asset: Dict[int, CalibrationRecord] = {}
    # En önce next_calibration'a göre sırala (desc), sonra id'ye göre (desc)
    qs = CalibrationRecord.objects.order_by("asset_id", "-next_calibration", "-id")
    for rec in qs:
        if rec.asset_id not in latest_for_asset:
            latest_for_asset[rec.asset_id] = rec
    return latest_for_asset

def _due_within_days(latest_map: Dict[int, CalibrationRecord], days: int) -> List[Dict[str, Any]]:
    today = _today()
    horizon = today + timedelta(days=days)
    rows: List[Dict[str, Any]] = []
    for asset in CalibrationAsset.objects.filter(is_active=True).order_by("asset_code"):
        rec = latest_map.get(asset.id)
        if not rec:
            continue
        nxt = rec.next_calibration
        lst = rec.last_calibration
        # next_calibration yoksa hatırlatma kapsamına alma (periyot hesabı bu sürümde yok)
        if not nxt:
            continue
        # kapsam: bugün..horizon ya da zaten gecikmiş (nxt <= today)
        if nxt <= horizon:
            days_left = (nxt - today).days
            rows.append(
                {
                    "asset": asset,
                    "record": rec,
                    "last_calibration": lst,
                    "next_calibration": nxt,
                    "days_left": days_left,
                }
            )
    # En acile göre sırala: days_left (küçükten büyüğe)
    rows.sort(key=lambda r: (r["days_left"], r["asset"].asset_code))
    return rows

def _group_by_responsible(rows: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """
    Sorumlu e-postaya göre grupla. E-posta yoksa 'no-email' grubuna at.
    """
    out: Dict[str, List[Dict[str, Any]]] = {}
    for r in rows:
        email = (r["asset"].responsible_email or "").strip().lower() or "no-email"
        out.setdefault(email, []).append(r)
    return out

class Command(BaseCommand):
    help = "Önümüzdeki X gün içinde kalibrasyon tarihi gelen cihazları e-posta ile hatırlatır (gruplu)."

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=30, help="Gün ufku (default: 30)")
        parser.add_argument("--to", action="append", default=[], help="Tüm liste ayrıca bu adrese de gönderilsin (bilgi amaçlı). Çoklu kullanılabilir.")
        parser.add_argument("--dry", action="store_true", help="E-posta göndermeden konsola dök")

    def handle(self, *args, **opts):
        days: int = opts["days"]
        force_to: List[str] = opts["to"]
        dry: bool = bool(opts["dry"])

        latest_map = _select_latest_record_map()
        rows = _due_within_days(latest_map, days)

        if not rows:
            self.stdout.write(self.style.WARNING(f"Uyarı kapsamına giren kayıt yok (days={days})."))
            return

        # Konsolda kısa özet
        self.stdout.write(self.style.SUCCESS(f"Toplam {len(rows)} cihaz için hatırlatma oluşturulacak (days={days})."))

        # Grupla ve gönder
        grouped = _group_by_responsible(rows)

        # Geliştirme ortamında console backend kullanılıyor olabilir
        default_from = getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com")

        # Her sorumluya ayrı mail
        for email, items in grouped.items():
            context = {
                "days": days,
                "items": items,
                "today": _today(),
                "responsible_email": email if email != "no-email" else "",
            }
            subject = f"[Kalibrasyon] {days} gün içinde yaklaşan {len(items)} kayıt"
            html_body = render_to_string("maintenance/email/calibration_reminder_email.html", context)
            text_body = render_to_string("maintenance/email/calibration_reminder_email.txt", context)

            to_list: List[str] = []
            if email != "no-email":
                to_list.append(email)
            # force_to ekle
            to_list += [x for x in force_to if x]

            if not to_list:
                # E-posta yoksa sadece konsola yaz (ör. log)
                self.stdout.write(f"(no-email) {len(items)} kayıt – sorumlu e-posta tanımlı değil.")
                self.stdout.write(text_body)
                continue

            if dry:
                self.stdout.write(f"[DRY] To={to_list} | Subject={subject}")
                self.stdout.write(text_body)
                continue

            msg = EmailMultiAlternatives(
                subject=subject,
                body=text_body,
                from_email=default_from,
                to=to_list,
            )
            msg.attach_alternative(html_body, "text/html")
            msg.send()

        self.stdout.write(self.style.SUCCESS("E-posta hatırlatmaları tamam."))
# <<< BLOK SONU: ID:PY-COM-WKWJA9S0
