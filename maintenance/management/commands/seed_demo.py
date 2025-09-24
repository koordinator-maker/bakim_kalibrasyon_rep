# REV: 1.0 | 2025-09-24 | Hash: b7b2804c | Parça: 1/1
# -*- coding: utf-8 -*-
from __future__ import annotations
import random
from datetime import date, datetime, timedelta, time
from typing import List
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from maintenance.models import (
    Equipment, MaintenanceOrder, CalibrationRecord, MaintenanceChecklistItem, SparePart
)

DISC = [("ELEC","Elektrik"), ("MECH","Mekanik"), ("PNEU","Pnömatik")]
TYPES = ["PLN","PRD","BRK"]
STATUS = ["SCHEDULED","COMPLETED","OVERDUE"]

class Command(BaseCommand):
    help = "Demo amaçlı bakım verileri üretir."

    def add_arguments(self, parser):
        parser.add_argument("--count", type=int, default=60, help="Üretilecek iş emri adedi (default: 60)")

    @transaction.atomic
    def handle(self, *args, **opts):
        count = int(opts["count"])
        self.stdout.write(self.style.NOTICE(f"Seeding demo data (orders={count})..."))

        # Equipments
        eqs: List[Equipment] = []
        for i in range(1, 8):
            code = f"MC-{i:03d}"
            eq, _ = Equipment.objects.get_or_create(
                code=code,
                defaults=dict(
                    name=f"Hat {((i-1)//3)+1} Makine {i}",
                    area=f"Hat-{((i-1)//3)+1}",
                    discipline=random.choice([d[0] for d in DISC]),
                    criticality=random.randint(1,5),
                    is_active=True,
                ),
            )
            eqs.append(eq)

        # Spare parts
        for i in range(1, 10):
            SparePart.objects.get_or_create(
                name=f"Parça-{i:02d}",
                equipment=random.choice(eqs),
                defaults=dict(is_critical=random.choice([True, False]), stock_qty=random.randint(0, 25), min_qty=5),
            )

        # Checklist items
        checklist_names = ["Yağ seviyesi", "Kayış gerginliği", "Sensör temizlik", "Cıvata kontrol", "V kayışı"]
        for eq in eqs:
            for nm in random.sample(checklist_names, k=3):
                MaintenanceChecklistItem.objects.get_or_create(
                    equipment=eq, name=nm, defaults=dict(is_mandatory=True, frequency=random.choice(["DAILY","WEEKLY","MONTHLY","QTR","YEARLY"]))
                )

        # Calibration records
        today = timezone.localdate()
        for eq in eqs[:4]:
            last = today - timedelta(days=random.randint(100, 380))
            nxt = last + timedelta(days=365)
            CalibrationRecord.objects.get_or_create(
                equipment=eq, defaults=dict(last_calibration=last, next_calibration=nxt, result="OK")
            )

        # Maintenance orders
        tz = timezone.get_current_timezone()
        for _ in range(count):
            eq = random.choice(eqs)
            t = random.choices(TYPES, weights=[0.5, 0.2, 0.3])[0]
            st = random.choices(STATUS, weights=[0.5, 0.35, 0.15])[0]

            start_d = timezone.localdate() - timedelta(days=random.randint(0, 180))
            due_d = start_d + timedelta(days=random.randint(0, 14))

            completed_at = None
            if st == "COMPLETED":
                # due_d + rastgele saat → aware datetime
                naive = datetime.combine(due_d, time(hour=random.randint(1, 20)))
                completed_at = timezone.make_aware(naive, tz)

            MaintenanceOrder.objects.create(
                equipment=eq,
                order_type=t,
                title=f"{t} iş emri - {eq.code}",
                description="Oto-oluşturulan demo kaydı.",
                technician=random.choice(["Ali", "Ayşe", "Mehmet", "Derya", "John"]),
                start_date=start_d,
                due_date=due_d,
                completed_at=completed_at,
                status=st,
                duration_hours=round(random.uniform(0.5, 16.0), 2),
                cost_total=round(random.uniform(250, 5000), 2),
            )

        self.stdout.write(self.style.SUCCESS("Demo verileri eklendi."))
