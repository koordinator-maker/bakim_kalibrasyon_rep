from django.contrib import admin
from .models import Equipment

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "serial_number")  # sadece kesin olanlar
    search_fields = ("name", "serial_number")
    # Geçici olarak filtre yok (hata çıkaranları kaldırdık)
    # list_filter = ()
    def has_add_permission(self, request):
        return True
