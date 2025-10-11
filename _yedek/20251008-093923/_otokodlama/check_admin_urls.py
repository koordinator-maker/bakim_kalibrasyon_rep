import os, sys, django
sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE","core.settings_maintenance")
django.setup()
from django.contrib import admin
from django.urls import reverse
from maintenance.models import Equipment
print("Registered:", Equipment in admin.site._registry)
print("CL :", reverse(f"admin:{Equipment._meta.app_label}_{Equipment._meta.model_name}_changelist"))
print("ADD:", reverse(f"admin:{Equipment._meta.app_label}_{Equipment._meta.model_name}_add"))