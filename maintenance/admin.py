from django.contrib import admin
from .models import Equipment

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "serial_number", "location", "inventory_code", "department", "purchase_date")
    search_fields = ("name", "serial_number", "inventory_code", "location")
    list_filter = ("department", "purchase_date")
    # Add formunun engellenmediğinden emin olmak için:
    def has_add_permission(self, request):
        return True
