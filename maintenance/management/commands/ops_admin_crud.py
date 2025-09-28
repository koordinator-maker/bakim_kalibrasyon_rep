# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand
from maintenance.models import Equipment

class Command(BaseCommand):
    help = "Admin CRUD UI test verisini idempotent hazırlama/temizleme"

    def add_arguments(self, parser):
        parser.add_argument("--action", choices=["cleanup","ensure","prepare_set"], default="ensure")
        parser.add_argument("--code", default="EQ-CRUD-UI")
        parser.add_argument("--name", default="UI CRUD Cihazi 1")

    def handle(self, *args, **opts):
        action = opts["action"]
        code   = opts["code"]
        name   = opts["name"]

        if action == "cleanup":
            n, _ = Equipment.objects.filter(code=code).delete()
            self.stdout.write(f"[cleanup] code={code} deleted={n>0}")
            return

        if action == "ensure":
            obj, created = Equipment.objects.get_or_create(code=code, defaults={"name": name})
            if not created and obj.name != name:
                obj.name = name
                obj.save()
            self.stdout.write(f"[ensure] code={code} id={getattr(obj,'id',None)} created={created}")
            return

        if action == "prepare_set":
            for c, n in [
                ("EQ-CHANGE-001", "Change Baseline Cihazi"),
                ("EQ-DELETE-001", "Delete Confirm Cihazi"),
                ("EQ-SEARCH-001", "Arama Test 1"),
                ("EQ-SEARCH-002", "Arama Test 2"),
                ("EQ-SEARCH-003", "Arama Test 3"),
            ]:
                Equipment.objects.get_or_create(code=c, defaults={"name": n})
            self.stdout.write("[prepare_set] ok")