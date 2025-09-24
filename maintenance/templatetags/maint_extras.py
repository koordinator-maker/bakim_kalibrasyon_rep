# REV: 1.1 | 2025-09-24 | Hash: 1f64af44 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-8GQS0CVD
from django import template
# <<< BLOK SONU: ID:PY-IMP-8GQS0CVD
# >>> BLOK: HELPERS | Yardimci fonksiyonlar | ID:PY-HEL-2YCE8FE4
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
# <<< BLOK SONU: ID:PY-HEL-2YCE8FE4
