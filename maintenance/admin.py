# -*- coding: utf-8 -*-
from django.contrib import admin
from maintenance.models import Equipment
from core.admin_utils import make_active, make_inactive # Yeni oluşturulan utils

# core/urls.py tarafından beklenen özel admin sitesi tanımlanıyor
class MaintenanceAdminSite(admin.AdminSite):
    site_header = 'Bakım ve Kalibrasyon Yönetimi'
    site_title = 'Bakım Yönetimi'

admin_site = MaintenanceAdminSite(name='maintenance_admin')

# ----------------------------------------------------------------------

@admin.register(Equipment, site=admin_site)
class EquipmentAdmin(admin.ModelAdmin):
    # EQP-002 görevi için 'manufacturer' kolonu eklendi.
    list_display = ('code', 'name', 'manufacturer', 'discipline', 'criticality', 'is_active')
    list_filter = ('discipline', 'criticality', 'is_active')
    search_fields = ('code', 'name', 'area', 'manufacturer')
    list_editable = ('criticality', 'is_active')
    actions = [make_active, make_inactive]

# Diğer modeller buraya kaydedilebilir.
