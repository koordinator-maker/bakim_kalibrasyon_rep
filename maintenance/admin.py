from django.contrib import admin
from .models import Equipment

# Equipment modelini Django Admin paneline kaydeder.
@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    # Admin listeleme sayfasýnda gösterilecek alanlar
    list_display = ('name', 'serial_number', 'location', 'inventory_code')
    
    # Arama çubuðunda arama yapýlabilecek alanlar
    search_fields = ('name', 'serial_number', 'inventory_code')

    # Filtreleme seçenekleri
    list_filter = ('location',)
