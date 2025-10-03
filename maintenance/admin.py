from django.contrib import admin
from .models import Equipment

# Equipment modelini Django Admin paneline kaydeder.
@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    # Admin listeleme sayfas�nda g�sterilecek alanlar
    list_display = ('name', 'serial_number', 'location', 'inventory_code')
    
    # Arama �ubu�unda arama yap�labilecek alanlar
    search_fields = ('name', 'serial_number', 'inventory_code')

    # Filtreleme se�enekleri
    list_filter = ('location',)
