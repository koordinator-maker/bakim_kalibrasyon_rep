# -*- coding: utf-8 -*-
from __future__ import annotations

from django.contrib import admin
from django.contrib.admin import AdminSite
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.urls import path
from django import forms
import csv
from decimal import Decimal, InvalidOperation

from .models import (
    Equipment,
    MaintenanceChecklistItem,
    MaintenanceOrder,
    CalibrationAsset,
    CalibrationRecord,
)


class MaintenanceAdminSite(AdminSite):
    site_header = "Bakım Kalibrasyon"
    site_title = "Bakım Kalibrasyon"
    index_title = "Yönetim"

    # --- Yardımcı yönlendirmeler (Admin > Equipment) ---
    def equipment_list(self, request):
        # Django admin changelist ekranına yönlendir
        return redirect("admin:maintenance_equipment_changelist")

    def equipment_create(self, request):
        return redirect("admin:maintenance_equipment_add")

    # --- CSV export örneği (Kalibrasyon) ---
    def calibration_export_csv(self, request):
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="calibrations.csv"'
        w = csv.writer(response)
        w.writerow([
            "Cihaz Kodu", "Cihaz Adı", "Lokasyon", "Marka", "Model",
            "Seri No", "Son Kalibrasyon", "Sonraki Kalibrasyon",
            "Sonuç", "Sertifika No", "Toplam Sapma"
        ])
        qs = CalibrationRecord.objects.select_related("asset").all().order_by("-next_calibration")
        for r in qs:
            a = r.asset
            w.writerow([
                a.asset_code, a.asset_name, a.location, a.brand, a.model, a.serial_no,
                r.last_calibration or "", r.next_calibration or "", r.result or "", r.certificate_no or "", r.total_deviation or ""
            ])
        return response

    # --- Basit sayfalar (mevcut şablonlar varsa kullanılır) ---
    def dashboard(self, request):
        upcoming_orders = MaintenanceOrder.objects.order_by("due_date")[:20]
        upcoming_cals = CalibrationRecord.objects.order_by("next_calibration")[:20]
        kpis = {"total_cost": 0, "avg_cost": 0, "total_duration": 0, "total_orders": MaintenanceOrder.objects.count()}
        extras = {"mtbf": 0, "mttr": 0, "schedule": 0, "pdm": 0, "brk_ratio": 0, "cal_comp": 0}
        return render(request, "maintenance/dashboard.html", {
            "upcoming_orders": upcoming_orders,
            "upcoming_cals": upcoming_cals,
            "kpis": kpis,
            "extras": extras,
            "type_counts": {},
            "status_counts": {},
            "by_discipline": [],
        })

    def orders(self, request):
        orders = MaintenanceOrder.objects.select_related("equipment").all().order_by("-due_date")
        return render(request, "maintenance/orders.html", {"orders": orders})

    def order_create(self, request):  # yer tutucu
        return redirect("admin:maintenance-orders")

    # ---- Kalibrasyon menüsü (şablonlar mevcutsa render eder) ----
    def _parse_limit(self, txt: str) -> Decimal | None:
        if not txt:
            return None
        s = ""
        for ch in txt:
            if ch.isdigit() or ch in ",.-":
                s += ch
            elif s:
                break
        s = s.replace(",", ".")
        try:
            return Decimal(s)
        except Exception:
            return None

    def calibration_list(self, request):
        assets = CalibrationAsset.objects.select_related("equipment").order_by("asset_code")
        return render(request, "maintenance/calibration_list.html", {"assets": assets})

    def calibration_follow(self, request):
        rows = []
        assets = CalibrationAsset.objects.order_by("asset_code")
        for a in assets:
            rec = a.records.order_by("-last_calibration", "-id").first()
            limit = self._parse_limit(a.acceptance_criteria)
            status = ""
            status_class = "chip"
            total_dev = None
            if rec and rec.total_deviation is not None and limit is not None:
                try:
                    total_dev = Decimal(rec.total_deviation)
                    if abs(total_dev) <= limit:
                        status = "Uygun"; status_class += " ok"
                    else:
                        status = "Uygun Değil"; status_class += " late"
                except InvalidOperation:
                    status = "Değerlendirilemedi"
            elif rec and rec.result:
                status = rec.result
                status_class += " ok" if rec.result.lower().startswith(("ok", "uygun")) else "late"
            else:
                status = "Kayıt Yok"; status_class += " due"

            rows.append({
                "asset": a, "record": rec, "limit": limit,
                "total_dev": total_dev, "status": status, "status_class": status_class,
            })
        return render(request, "maintenance/calibration_table.html", {"rows": rows})

    class CalibrationAssetForm(forms.ModelForm):
        class Meta:
            model = CalibrationAsset
            fields = [
                "asset_code","asset_name","location","brand","model","serial_no",
                "measure_range","resolution","unit","accuracy","uncertainty",
                "acceptance_criteria","calibration_method","standard_device",
                "standard_id","owner","responsible_email","equipment","is_active",
            ]
            widgets = {
                "asset_code": forms.TextInput(attrs={"class": "input-lg"}),
                "asset_name": forms.TextInput(attrs={"class": "input-lg"}),
                "acceptance_criteria": forms.TextInput(attrs={"placeholder": "örn: ±0.05"}),
            }

    def cal_asset_create(self, request):
        Form = self.CalibrationAssetForm
        if request.method == "POST":
            form = Form(request.POST)
            if form.is_valid():
                form.save()
                return redirect("admin:maintenance-calibrations")
        else:
            form = Form()
        return render(request, "maintenance/calibration_asset_form.html", {"form": form})

    class CalibrationRecordForm(forms.ModelForm):
        RESULT_CHOICES = (("Uygun","Uygun"),("Uygun Değil","Uygun Değil"),("Bilgi","Bilgi"))
        result = forms.ChoiceField(choices=RESULT_CHOICES, required=False)
        class Meta:
            model = CalibrationRecord
            fields = ["asset","last_calibration","certificate_no","total_deviation","result","next_calibration","notes"]
            widgets = {
                "last_calibration": forms.DateInput(attrs={"type": "date"}),
                "next_calibration": forms.DateInput(attrs={"type": "date"}),
            }

    def cal_record_create(self, request):
        Form = self.CalibrationRecordForm
        if request.method == "POST":
            form = Form(request.POST)
            if form.is_valid():
                form.save()
                return redirect("admin:maintenance-calibrations")
        else:
            form = Form()
        return render(request, "maintenance/calibration_record_form.html", {"form": form})

    class AssetLookupForm(forms.Form):
        asset = forms.ModelChoiceField(
            label="Cihaz",
            queryset=CalibrationAsset.objects.order_by("asset_code"),
            required=True
        )

    def calibration_info(self, request):
        selected = None
        form = self.AssetLookupForm(request.GET or None)
        last_record = None
        if form.is_valid():
            selected = form.cleaned_data["asset"]
            last_record = selected.records.order_by("-last_calibration","-id").first()
        return render(request, "maintenance/calibration_asset_detail.html", {
            "form": form, "asset": selected, "record": last_record
        })

    def cal_assets_all(self, request):
        assets = CalibrationAsset.objects.select_related("equipment").order_by("location","asset_code")
        return render(request, "maintenance/calibration_assets_all.html", {"assets": assets})

    def calibration_remind(self, request):
        return HttpResponse("Kalibrasyon hatırlatma kuru çalıştırma (dev).")

    def checklists(self, request):
        items = (MaintenanceChecklistItem.objects
                 .select_related("equipment")
                 .all().order_by("equipment__code","id"))
        return render(request, "maintenance/checklists.html", {"items": items})

    class ChecklistCreateForm(forms.Form):
        # alan adları ascii, etiketler TR
        bulundugu_bolum = forms.CharField(label="Bulunduğu bölüm", max_length=120, required=False,
                                          widget=forms.TextInput(attrs={"class":"input-lg"}))
        makine_no = forms.CharField(label="Makine No", max_length=50,
                                    widget=forms.TextInput(attrs={"class":"input-lg"}))
        makine_adi = forms.CharField(label="Makine Adı", max_length=200,
                                     widget=forms.TextInput(attrs={"class":"input-lg"}))
        uretici_firma = forms.CharField(label="Üretici Firma", max_length=200, required=False,
                                        widget=forms.TextInput(attrs={"class":"input-lg"}))
        bakım_kontrol_periyodu = forms.ChoiceField(
            label="Bakım / Kontrol Periyodu",
            choices=MaintenanceChecklistItem.FREQ,
            widget=forms.Select(attrs={"class":"input-lg"})
        )
        bakım_kontrol_tanımı = forms.CharField(
            label="Bakım / Kontrol Tanımı",
            max_length=200,
            widget=forms.TextInput(attrs={"class":"input-lg"})
        )
        existing_equipment = forms.ModelChoiceField(
            label="(İsteğe bağlı) Mevcut Makine",
            queryset=Equipment.objects.all().order_by("code"),
            required=False
        )

    def checklist_create(self, request):
        FormCls = self.ChecklistCreateForm
        if request.method == "POST":
            form = FormCls(request.POST)
            if form.is_valid():
                eq = form.cleaned_data.get("existing_equipment")
                if not eq:
                    code = form.cleaned_data["makine_no"].strip()
                    name = form.cleaned_data["makine_adi"].strip()
                    area = form.cleaned_data.get("bulundugu_bolum","").strip()
                    manufacturer = form.cleaned_data.get("uretici_firma","").strip()
                    eq, _ = Equipment.objects.get_or_create(code=code, defaults={
                        "name": name, "area": area, "manufacturer": manufacturer,
                        "discipline": "MECH", "criticality": 3, "is_active": True,
                    })
                    changed = False
                    if eq.name != name: eq.name = name; changed = True
                    if area and eq.area != area: eq.area = area; changed = True
                    if manufacturer and getattr(eq,"manufacturer","") != manufacturer:
                        eq.manufacturer = manufacturer; changed = True
                    if changed: eq.save()

                freq = form.cleaned_data["bakım_kontrol_periyodu"]
                desc = form.cleaned_data["bakım_kontrol_tanımı"].strip()
                MaintenanceChecklistItem.objects.create(
                    equipment=eq, name=desc, frequency=freq, is_mandatory=True
                )
                return redirect("admin:maintenance-checklists")
        else:
            form = FormCls()
        return render(request, "maintenance/form_checklist.html", {"form": form, "title": "Yeni Checklist Maddesi"})

    # --- URL haritası ---
    def get_urls(self):
        my = [
            # Yardımcı yönlendirme: Equipment listesi (FLOW burayı kullanacak)
            path("maintenance/equipment/list/",
                 self.admin_view(self.equipment_list),
                 name="maintenance-equipment-list"),
            path("maintenance/equipment/new/",
                 self.admin_view(self.equipment_create),
                 name="maintenance-equipment-create"),

            # Dashboard & orders
            path("maintenance/dashboard/", self.admin_view(self.dashboard), name="maintenance-dashboard"),
            path("maintenance/orders/", self.admin_view(self.orders), name="maintenance-orders"),
            path("maintenance/orders/new/", self.admin_view(self.order_create), name="maintenance-order-create"),

            # Kalibrasyon
            path("maintenance/calibrations/", self.admin_view(self.calibration_list), name="maintenance-calibrations"),
            path("maintenance/calibrations/follow/", self.admin_view(self.calibration_follow), name="maintenance-calibration-follow"),
            path("maintenance/calibrations/asset/new/", self.admin_view(self.cal_asset_create), name="maintenance-cal-asset-create"),
            path("maintenance/calibrations/record/new/", self.admin_view(self.cal_record_create), name="maintenance-calibration-create"),
            path("maintenance/calibrations/info/", self.admin_view(self.calibration_info), name="maintenance-calibration-info"),
            path("maintenance/calibrations/assets/", self.admin_view(self.cal_assets_all), name="maintenance-calibration-assets"),
            path("maintenance/calibrations/remind/", self.admin_view(self.calibration_remind), name="maintenance-calibration-remind"),
            path("maintenance/calibrations/export/", self.admin_view(self.calibration_export_csv), name="maintenance-calibration-export"),

            # Checklist
            path("maintenance/checklists/", self.admin_view(self.checklists), name="maintenance-checklists"),
            path("maintenance/checklists/new/", self.admin_view(self.checklist_create), name="maintenance-checklist-create"),
        ]
        return my + super().get_urls()


# Özel admin site örneği
admin_site = MaintenanceAdminSite(name="admin")

# Model kayıtları (custom site'e)
@admin.register(Equipment, site=admin_site)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ("code","name","area","manufacturer","discipline","criticality","is_active")
    search_fields = ("code","name","area","manufacturer")
    list_filter = ("discipline","is_active")


@admin.register(MaintenanceChecklistItem, site=admin_site)
class MaintenanceChecklistItemAdmin(admin.ModelAdmin):
    list_display = ("equipment","name","frequency","is_mandatory")
    list_filter = ("frequency","is_mandatory")
    search_fields = ("equipment__code","equipment__name","name")


@admin.register(MaintenanceOrder, site=admin_site)
class MaintenanceOrderAdmin(admin.ModelAdmin):
    list_display = ("title","equipment","order_type","status","due_date","cost_total")
    list_filter = ("order_type","status")
    search_fields = ("title","equipment__code","equipment__name")


@admin.register(CalibrationAsset, site=admin_site)
class CalibrationAssetAdmin(admin.ModelAdmin):
    list_display = ("asset_code","asset_name","location","brand","model","serial_no","equipment")
    search_fields = ("asset_code","asset_name","brand","model","serial_no")
    list_filter = ("brand",)


@admin.register(CalibrationRecord, site=admin_site)
class CalibrationRecordAdmin(admin.ModelAdmin):
    list_display = ("asset","last_calibration","next_calibration","result","certificate_no","total_deviation")
    list_filter = ("result","next_calibration")
    search_fields = ("asset__asset_code","asset__asset_name","certificate_no")