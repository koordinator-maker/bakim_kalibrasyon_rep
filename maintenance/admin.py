# -*- coding: utf-8 -*-
from __future__ import annotations
from datetime import date, timedelta

from django.contrib import admin
from django.urls import path
from django.shortcuts import render, redirect
from django.db.models import Count, Sum
from django.core.mail import send_mail
from django.conf import settings

from .models import (
    Equipment, MaintenanceOrder, MaintenanceChecklistItem, SparePart,
    CalibrationAsset, CalibrationRecord
)
from .forms import (
    MaintenanceOrderForm, CalibrationRecordForm, MaintenanceChecklistItemForm, CalibrationAssetForm
)
from .kpi_helpers import (
    cost_summary, mtbf_hours, mttr_hours, schedule_compliance, pdm_hit_rate, breakdown_ratio, calibration_compliance
)
import csv
from django.http import HttpResponse

# --- Standart admin kayıtları ---
@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "area", "discipline", "criticality", "is_active")
    list_filter = ("discipline", "is_active")

@admin.register(MaintenanceOrder)
class MaintenanceOrderAdmin(admin.ModelAdmin):
    list_display = ("title", "equipment", "order_type", "status", "due_date", "duration_hours", "cost_total")
    list_filter = ("order_type", "status", "equipment__discipline")

@admin.register(SparePart)
class SparePartAdmin(admin.ModelAdmin):
    list_display = ("name", "equipment", "is_critical", "stock_qty", "min_qty")
    list_filter = ("is_critical",)

# --- Özel admin site ve sayfalar ---
class MaintenanceAdminSite(admin.AdminSite):
    site_header = "Bakım Kalibrasyon"

    def get_urls(self):
        urls = super().get_urls()
        my = [
            path("maintenance/dashboard/", self.admin_view(self.dashboard), name="maintenance-dashboard"),
            path("maintenance/orders/", self.admin_view(self.orders), name="maintenance-orders"),
            path("maintenance/orders/new/", self.admin_view(self.order_create), name="maintenance-order-create"),

            path("maintenance/calibrations/", self.admin_view(self.calibration_list), name="maintenance-calibrations"),
            path("maintenance/calibrations/asset/new/", self.admin_view(self.cal_asset_create), name="maintenance-cal-asset-create"),
            path("maintenance/calibrations/record/new/", self.admin_view(self.cal_record_create), name="maintenance-calibration-create"),
            path("maintenance/calibrations/remind/", self.admin_view(self.calibration_remind), name="maintenance-calibration-remind"),
            path("maintenance/calibrations/export/", self.admin_view(self.calibration_export_csv), name="maintenance-calibration-export"),

            path("maintenance/checklists/", self.admin_view(self.checklists), name="maintenance-checklists"),
            path("maintenance/checklists/new/", self.admin_view(self.checklist_create), name="maintenance-checklist-create"),
        ]
        return my + urls
    def calibration_export_csv(self, request):
        # Tüm cihaz + son kayıt özetini CSV olarak indir
        assets = CalibrationAsset.objects.all().order_by("asset_code")
        latest_map = {}
        for r in CalibrationRecord.objects.order_by("asset_id", "-next_calibration", "-id"):
            latest_map.setdefault(r.asset_id, r)

        resp = HttpResponse(content_type="text/csv; charset=utf-8")
        resp["Content-Disposition"] = 'attachment; filename="calibrations_export.csv"'
        w = csv.writer(resp)
        w.writerow([
            "Cihaz Kodu","Cihaz Adı","Lokasyon","Marka","Model","Seri No",
            "Ölçüm Aralığı","Çözünürlük","Birim","Doğruluk","Belirsizlik","Kabul Kriteri",
            "Yöntem","Standart Cihaz","Standart ID",
            "Son Kalibrasyon","Sonraki Kalibrasyon","Sonuç",
            "Sorumlu","E-posta","EkipmanKodu"
        ])
        for a in assets:
            r = latest_map.get(a.id)
            w.writerow([
                a.asset_code, a.asset_name, a.location, a.brand, a.model, a.serial_no,
                a.measure_range, a.resolution, a.unit, a.accuracy, a.uncertainty, a.acceptance_criteria,
                a.calibration_method, a.standard_device, a.standard_id,
                getattr(r, "last_calibration", "") or "", getattr(r, "next_calibration", "") or "", getattr(r, "result", "") or "",
                a.owner, a.responsible_email, getattr(a.equipment, "code", "") or ""
            ])
        return resp

    # ---- Views ----
    def dashboard(self, request):
        ctx = {}
        ctx["kpis"] = cost_summary()
        ctx["extras"] = {
            "mtbf": mtbf_hours(180),
            "mttr": mttr_hours(180),
            "schedule": schedule_compliance(90),
            "pdm": pdm_hit_rate(90),
            "brk_ratio": breakdown_ratio(90),
            "cal_comp": calibration_compliance(365),
        }
        ctx["type_counts"] = dict(
            MaintenanceOrder.objects.values_list("order_type").annotate(c=Count("id")).values_list("order_type", "c")
        )
        ctx["status_counts"] = dict(
            MaintenanceOrder.objects.values_list("status").annotate(c=Count("id")).values_list("status", "c")
        )
        ctx["by_discipline"] = (
            MaintenanceOrder.objects.values("equipment__discipline")
            .annotate(cost=Sum("cost_total"))
            .order_by("equipment__discipline")
        )
        today = date.today()
        ctx["upcoming_orders"] = MaintenanceOrder.objects.filter(
            order_type__in=["PLN", "PRD"], due_date__gte=today, due_date__lte=today + timedelta(days=30)
        ).select_related("equipment").order_by("due_date")[:20]
        ctx["upcoming_cals"] = CalibrationRecord.objects.filter(
            next_calibration__gte=today, next_calibration__lte=today + timedelta(days=30)
        ).select_related("asset")[:20]
        return render(request, "maintenance/dashboard.html", ctx)

    def orders(self, request):
        rows = MaintenanceOrder.objects.select_related("equipment").all()[:300]
        return render(request, "maintenance/list_orders.html", {"rows": rows, "title": "İş Emirleri"})

    def order_create(self, request):
        if request.method == "POST":
            form = MaintenanceOrderForm(request.POST)
            if form.is_valid():
                form.save()
                return redirect("admin:maintenance-orders")
        else:
            form = MaintenanceOrderForm()
        return render(request, "maintenance/form_order.html", {"form": form, "title": "Yeni İş Emri"})

    # ---- KALİBRASYON ----
    def calibration_list(self, request):
        assets = CalibrationAsset.objects.all().order_by("asset_code")
        # Her asset için en güncel record'u map edelim
        latest_map = {}
        for r in CalibrationRecord.objects.order_by("asset_id", "-next_calibration", "-id"):
            latest_map.setdefault(r.asset_id, r)
        ctx = {
            "title": "Kalibrasyonlar",
            "assets": assets,
            "latest_map": latest_map,
        }
        return render(request, "maintenance/list_calibrations.html", ctx)

    def cal_asset_create(self, request):
        if request.method == "POST":
            form = CalibrationAssetForm(request.POST)
            if form.is_valid():
                form.save()
                return redirect("admin:maintenance-calibrations")
        else:
            form = CalibrationAssetForm()
        return render(request, "maintenance/form_cal_asset.html", {"form": form, "title": "Yeni Kalibrasyon Cihazı"})

    def cal_record_create(self, request):
        if request.method == "POST":
            form = CalibrationRecordForm(request.POST)
            if form.is_valid():
                form.save()
                return redirect("admin:maintenance-calibrations")
        else:
            form = CalibrationRecordForm()
        return render(request, "maintenance/form_cal_record.html", {"form": form, "title": "Yeni Kalibrasyon Kaydı"})

    def checklists(self, request):
        rows = MaintenanceChecklistItem.objects.select_related("equipment").all()[:500]
        return render(request, "maintenance/list_checklists.html", {"rows": rows, "title": "Checklistler"})

    def checklist_create(self, request):
        if request.method == "POST":
            form = MaintenanceChecklistItemForm(request.POST)
            if form.is_valid():
                form.save()
                return redirect("admin:maintenance-checklists")
        else:
            form = MaintenanceChecklistItemForm()
        return render(request, "maintenance/form_checklist.html", {"form": form, "title": "Yeni Checklist Maddesi"})

    def calibration_remind(self, request):
        """
        Gelecek 30 gün içindeki kalibrasyonları sorumlulara e-posta ile gönderir.
        """
        days = int(request.GET.get("days", 30))
        today = date.today()
        qs = (
            CalibrationRecord.objects.filter(next_calibration__gte=today, next_calibration__lte=today + timedelta(days=days))
            .select_related("asset")
            .order_by("next_calibration")
        )
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
            body = (
                "Aşağıdaki cihazların kalibrasyon tarihi yaklaşıyor:\n\n"
                + "\n".join(lines)
                + "\n\nBu bildirim sistem tarafından otomatik oluşturulmuştur."
            )
            try:
                send_mail(
                    subject="Yaklaşan Kalibrasyonlar",
                    message=body,
                    from_email=getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
                    recipient_list=[mail],
                    fail_silently=True,
                )
                sent += 1
            except Exception:
                pass

        self.message_user(request, f"E-posta gönderimi tamamlandı. Gruplar: {sent}, kayıtlar: {qs.count()}.")
        return redirect("admin:maintenance-calibrations")


# Varsayılan admin site zaten çalışıyorsa bunu import etmek yeterli.
admin_site = MaintenanceAdminSite()
