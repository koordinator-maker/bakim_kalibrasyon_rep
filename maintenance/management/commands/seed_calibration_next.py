# REV: 1.1 | 2025-09-25 | Hash: 8dd154fb | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-Q39NYKQ7
# -*- coding: utf-8 -*-
from __future__ import annotations

import random
# <<< BLOK SONU: ID:PY-IMP-Q39NYKQ7
# >>> BLOK: COMMAND | Komut | ID:PY-COM-SGZCGYTS
from datetime import date, timedelta

from django.core.management.base import BaseCommand
from django.db.models import OuterRef, Subquery, DateField

from maintenance.models import CalibrationAsset, CalibrationRecord


class Command(BaseCommand):
    help = (
        "Gelecek tarihli demo kalibrasyon kayıtları üretir.\n"
        "Varsayılan: sadece eksik/geride olanlara, bugün+10..90 gün arası next_calibration oluşturur.\n"
        "Örnek:\n"
        "  python manage.py seed_calibration_next --settings=core.settings_maintenance\n"
        "  python manage.py seed_calibration_next --days-min 7 --days-max 120 --force --settings=core.settings_maintenance\n"
    )

    def add_arguments(self, parser):
        parser.add_argument("--days-min", type=int, default=10, help="Next calibration en az gün (vars: 10)")
        parser.add_argument("--days-max", type=int, default=90, help="Next calibration en çok gün (vars: 90)")
        parser.add_argument(
            "--force",
            action="store_true",
            help="Tüm aktif cihazlara yeni kayıt ekler (mevcutta geleceğe dönük olsa bile).",
        )

    def handle(self, *args, **opts):
        dmin = max(1, int(opts["days_min"]))
        dmax = max(dmin, int(opts["days_max"]))
        force = bool(opts["force"])

        today = date.today()

        latest_next = CalibrationRecord.objects.filter(
            asset_id=OuterRef("pk")
        ).order_by("-next_calibration").values("next_calibration")[:1]

        assets = (
            CalibrationAsset.objects.filter(is_active=True)
            .annotate(next_cal=Subquery(latest_next, output_field=DateField()))
            .order_by("asset_code")
        )

        created = 0
        for a in assets:
            if not force and a.next_cal and a.next_cal >= today:
                # Zaten geleceğe dönük bir next_calibration var
                continue

            # last: geçen 100..400 gün önce
            last_days_ago = random.randint(100, 400)
            last = today - timedelta(days=last_days_ago)
            # next: dmin..dmax gün sonra
            nxt = today + timedelta(days=random.randint(dmin, dmax))

            CalibrationRecord.objects.create(
                asset=a,
                last_calibration=last,
                next_calibration=nxt,
                result="OK",
                notes="Demo seed (seed_calibration_next)",
            )
            created += 1

        self.stdout.write(self.style.SUCCESS(f"Oluşturulan kalibrasyon kaydı: {created}"))
# <<< BLOK SONU: ID:PY-COM-SGZCGYTS
