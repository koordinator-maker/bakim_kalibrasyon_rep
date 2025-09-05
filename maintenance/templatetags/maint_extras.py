from django import template
register = template.Library()

@register.filter
def get_item(d, key):
    try:
        return d.get(key)
    except Exception:
        return None

@register.filter
def status_badge(date_obj):
    # basit durum rengi: geçmiş = kırmızı, 30 gün içinde = turuncu, aksi = normal
    from datetime import date, timedelta
    if not date_obj:
        return "badge"
    today = date.today()
    if date_obj < today:
        return "badge danger"
    if date_obj <= today + timedelta(days=30):
        return "badge warn"
    return "badge"
