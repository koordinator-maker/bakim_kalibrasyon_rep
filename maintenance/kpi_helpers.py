# REV: 1.1 | 2025-09-24 | Hash: 79d127ef | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-VER4SXB2
# -*- coding: utf-8 -*-
from __future__ import annotations
# <<< BLOK SONU: ID:PY-IMP-VER4SXB2
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-CSMB3X32
from datetime import datetime, date, time, timedelta
from typing import Optional

from django.conf import settings
from django.db.models import Sum, Avg, Count, Q
from django.utils import timezone

from .models import MaintenanceOrder, CalibrationRecord

# ---- helpers ---------------------------------------------------------------

def _to_aware(dt: datetime) -> datetime:
    """
    Datetime'i timezone-aware hale getirir (USE_TZ=True iken).
    Zaten aware ise olduğu gibi döner.
    """
    if dt is None:
        return None
    if timezone.is_aware(dt):
        return dt
    return timezone.make_aware(dt, timezone.get_current_timezone())

def _date_to_aware_start(d: Optional[date]) -> Optional[datetime]:
    """
    Date -> aynı günün 00:00 aware datetime'ı.
    None gelirse None döner.
    """
    if d is None:
        return None
    dt = datetime.combine(d, time.min)
    return _to_aware(dt)

# ---- KPIs ------------------------------------------------------------------

def mtbf_hours(days: int = 180) -> float:
    """Arızalar arası ort. süre. Basit yaklaşım: tamamlanan BRK sayısına göre."""
    now = timezone.now()
    since = now - timedelta(days=days)
    # Tamamlanmış arızalar
    brk_cnt = (
        MaintenanceOrder.objects.filter(order_type="BRK", completed_at__isnull=False, completed_at__gte=since)
        .count()
    )
    if brk_cnt <= 1:
        return 0.0
    # Ölçüm penceresini saat olarak böl.
    hours = days * 24.0
    return round(hours / brk_cnt, 1)

def mttr_hours(days: int = 180) -> float:
    """
    Mean Time To Repair: (completed_at - start_date)
    start_date bir DateField olduğu için aware datetime'a dönüştürülür.
    """
    now = timezone.now()
    since = now - timedelta(days=days)
    qs = MaintenanceOrder.objects.filter(
        completed_at__isnull=False,
        completed_at__gte=since,
    ).only("completed_at", "start_date")
    total = 0.0
    n = 0
    for mo in qs:
        start_dt = _date_to_aware_start(mo.start_date)
        end_dt = _to_aware(mo.completed_at)
        if start_dt and end_dt and end_dt >= start_dt:
            total += (end_dt - start_dt).total_seconds() / 3600.0
            n += 1
    return round(total / n, 1) if n else 0.0

def schedule_compliance(days: int = 90) -> float:
    """Planlı işlerin zamanında tamamlama oranı (örnek basit hesap)."""
    now = timezone.now().date()
    since = now - timedelta(days=days)
    planned = MaintenanceOrder.objects.filter(
        order_type="PLN", start_date__gte=since
    )
    total = planned.count()
    if total == 0:
        return 0.0
    ontime = planned.filter(
        status="COMPLETED", completed_at__isnull=False, due_date__isnull=False
    ).filter(
        completed_at__lte=_to_aware(datetime.combine(timezone.localdate(), time.max))
    ).count()
    return round(ontime * 100.0 / total, 1)

def pdm_hit_rate(days: int = 90) -> float:
    """Kestirimci işlerin isabet oranı (placeholder)."""
    now = timezone.now().date()
    since = now - timedelta(days=days)
    qs = MaintenanceOrder.objects.filter(order_type="PRD", start_date__gte=since)
    total = qs.count()
    if total == 0:
        return 0.0
    # Örnek metrik: tamamlanan / toplam
    hit = qs.filter(status="COMPLETED").count()
    return round(hit * 100.0 / total, 1)

def breakdown_ratio(days: int = 90) -> float:
    """Arızi işlerin, toplam işlere oranı."""
    now = timezone.now().date()
    since = now - timedelta(days=days)
    total = MaintenanceOrder.objects.filter(start_date__gte=since).count()
    if total == 0:
        return 0.0
    brk = MaintenanceOrder.objects.filter(order_type="BRK", start_date__gte=since).count()
    return round(brk * 100.0 / total, 1)

def calibration_compliance(days: int = 365) -> float:
    """Kalibrasyon kayıtlarında gelecek/son 1 yılda uyum oranı (placeholder)."""
    now = timezone.localdate()
    start = now - timedelta(days=days)
    end = now + timedelta(days=days)
    qs = CalibrationRecord.objects.filter(next_calibration__gte=start, next_calibration__lte=end)
    total = qs.count()
    if total == 0:
        return 0.0
    ok = qs.filter(result__iexact="OK").count()
    return round(ok * 100.0 / total, 1)

def cost_summary(days: int = 180) -> dict:
    """Toplam/ortalama maliyet ve süre, iş emri adedi."""
    now = timezone.now().date()
    since = now - timedelta(days=days)
    agg = MaintenanceOrder.objects.filter(start_date__gte=since).aggregate(
        total_cost=Sum("cost_total"),
        avg_cost=Avg("cost_total"),
        total_duration=Sum("duration_hours"),
        total_orders=Count("id"),
    )
    # None güvenliği
    for k in ("total_cost", "avg_cost", "total_duration", "total_orders"):
        agg[k] = agg[k] or 0
    return agg
# <<< BLOK SONU: ID:PY-HEL-CSMB3X32
