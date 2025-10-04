from django.contrib import admin
from .models import Equipment

# Equipment modelini Django Admin paneline kaydeder.
@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    # Admin listeleme sayfasÃ„Â±nda gÃƒÂ¶sterilecek alanlar
    list_display = ('name', 'serial_number', 'location', 'inventory_code')
    
    # Arama ÃƒÂ§ubuÃ„Å¸unda arama yapÃ„Â±labilecek alanlar
    search_fields = ('name', 'serial_number', 'inventory_code')

    # Filtreleme seÃƒÂ§enekleri
    list_filter = ('location',)
