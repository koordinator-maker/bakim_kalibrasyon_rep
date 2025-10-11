from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.apps import apps
User = get_user_model()
u, created = User.objects.get_or_create(username='admin', defaults={'email':'admin@example.com','is_superuser':True,'is_staff':True})
if created:
    u.set_password('admin')
    u.save()
Equipment = apps.get_model('maintenance','Equipment')
if Equipment:
    ct = apps.get_model('contenttypes','ContentType').objects.get_for_model(Equipment)
    try:
        p = Permission.objects.get(codename='add_equipment', content_type=ct)
        u.user_permissions.add(p)
    except Permission.DoesNotExist:
        pass
print("OK-user:", u.username)