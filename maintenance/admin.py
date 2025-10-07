from django.contrib import admin
from .models import Equipment

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'serial_number', 'location', 'manufacturer', 'is_active')
    list_filter = ('location', 'is_active')
    search_fields = ('name', 'serial_number')
    
    # EQP-003 testi için 'manufacturer' alanının formda görünür olduğundan emin olunur.
    fieldsets = (
        (None, {
            'fields': ('name', 'serial_number', 'manufacturer', 'purchase_date', 'last_maintenance_date', 'next_maintenance_date', 'location', 'is_active')
        }),
    )
