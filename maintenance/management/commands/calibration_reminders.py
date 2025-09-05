# -*- coding: utf-8 -*-
from __future__ import annotations
from datetime import date, timedelta
from django.core.management.base import BaseCommand
from django.core.mail import send_mail
from django.conf import settings
from maintenance.models import CalibrationRecord

class Command(BaseCommand):
    help = "Yaklaşan kalibrasyonları sorumlulara e-posta atar (varsayılan 30 gün)."

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=30)

    def handle(self, *args, **opts):
        days = int(opts["days"])
        today = date.today()
        qs = CalibrationRecord.objects.select_related("asset").filter(
            next_calibration__gte=today, next_calibration__lte=today + timedelta(days=days)
        ).order_by("next_calibration")

        groups = {}
        for r in qs:
            mail = (r.asset.responsible_email or "").strip().lower()
            if not mail:
                continue
            groups.setdefault(mail, []).append(r)

        sent = 0
        for mail, items in groups.items():
            lines = [
                f"- {r.next_calibration:%d.%m.%Y} | {r.asset.asset_code} {r.asset.asset_name} | {r.asset.location} | {r.result or '-'}"
                for r in items
            ]
            body = "Aşağıdaki cihazların kalibrasyon tarihi yaklaşıyor:\n\n" + "\n".join(lines)
            send_mail(
                subject="Yaklaşan Kalibrasyonlar",
                message=body,
                from_email=getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
                recipient_list=[mail],
                fail_silently=True,
            )
            sent += 1

        self.stdout.write(self.style.SUCCESS(f"Gönderim tamam: grup={sent}, kayıt={qs.count()}"))
