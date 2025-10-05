from django.test import TestCase, Client
from django.contrib.auth import get_user_model
from django.contrib.admin.templatetags.admin_urls import admin_urlname
from django.urls import reverse
from maintenance.models import Equipment

class AdminSmokeTest(TestCase):
    def setUp(self):
        U = get_user_model()
        u, _ = U.objects.get_or_create(
            username="admin",
            defaults={"email": "admin@example.com", "is_staff": True, "is_superuser": True},
        )
        u.is_staff = True
        u.is_superuser = True
        u.set_password("admin123!")
        u.save()
        self.client = Client()
        self.client.force_login(u)

    def test_admin_equipment_pages(self):
        # index
        self.assertEqual(self.client.get(reverse("admin:index")).status_code, 200)

        # model URL'leri
        cl  = reverse(admin_urlname(Equipment._meta, "changelist"))
        add = reverse(admin_urlname(Equipment._meta, "add"))

        self.assertEqual(self.client.get(cl).status_code, 200, cl)
        self.assertEqual(self.client.get(add).status_code, 200, add)