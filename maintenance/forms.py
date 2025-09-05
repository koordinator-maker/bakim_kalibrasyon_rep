# -*- coding: utf-8 -*-
from django import forms
from .models import (
    MaintenanceOrder,
    CalibrationRecord,
    MaintenanceChecklistItem,
    CalibrationAsset,
)

class DateInput(forms.DateInput):
    input_type = "date"

class DateTimeInput(forms.DateTimeInput):
    input_type = "datetime-local"
    def format_value(self, value):
        if value is None:
            return ""
        try:
            return value.strftime("%Y-%m-%dT%H:%M")
        except Exception:
            return super().format_value(value)

class MaintenanceOrderForm(forms.ModelForm):
    class Meta:
        model = MaintenanceOrder
        fields = [
            "equipment", "order_type", "title", "description", "technician",
            "start_date", "due_date", "completed_at", "status",
            "duration_hours", "cost_total"
        ]
        widgets = {
            "start_date": DateInput(),
            "due_date": DateInput(),
            "completed_at": DateTimeInput(),
            "description": forms.Textarea(attrs={"rows": 3}),
        }

class CalibrationAssetForm(forms.ModelForm):
    class Meta:
        model = CalibrationAsset
        fields = [
            "equipment", "asset_code", "asset_name", "location",
            "brand", "model", "serial_no",
            "measure_range", "resolution", "unit",
            "accuracy", "uncertainty", "acceptance_criteria",
            "calibration_method", "standard_device", "standard_id",
            "owner", "responsible_email", "is_active",
        ]

class CalibrationRecordForm(forms.ModelForm):
    class Meta:
        model = CalibrationRecord
        fields = ["asset", "last_calibration", "next_calibration", "result", "certificate_no", "notes"]
        widgets = {
            "last_calibration": DateInput(),
            "next_calibration": DateInput(),
            "notes": forms.Textarea(attrs={"rows": 3}),
        }

class MaintenanceChecklistItemForm(forms.ModelForm):
    class Meta:
        model = MaintenanceChecklistItem
        fields = ["equipment", "name", "is_mandatory", "frequency"]
