# REV: 1.1 | 2025-09-25 | Hash: 3c61e1dd | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-74RSM79F
# -*- coding: utf-8 -*-
from __future__ import annotations

# <<< BLOK SONU: ID:PY-IMP-74RSM79F
# >>> BLOK: COMMAND | Komut | ID:PY-COM-4VYASZQ2
from typing import Dict, Iterable, List, Set

from django.apps import apps
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group, Permission
from django.contrib.contenttypes.models import ContentType
from django.core.management.base import BaseCommand


APP_LABEL = "maintenance"
GROUP_MANAGER = "Bakım Yöneticisi"
GROUP_TECH = "Teknisyen"
GROUP_OBS = "Gözlemci"

# Hedef izin matrisi:
# - Bakım Yöneticisi: CalibrationAsset & CalibrationRecord için add/change/delete/view
# - Teknisyen:        CalibrationRecord -> add/change/view;   CalibrationAsset -> view
# - Gözlemci:         her iki model -> view
MODEL_NAMES = ["CalibrationAsset", "CalibrationRecord"]


def _get_perms_for_models(model_names: Iterable[str]) -> Dict[str, Dict[str, Permission]]:
    out: Dict[str, Dict[str, Permission]] = {}
    for model_name in model_names:
        model = apps.get_model(APP_LABEL, model_name)
        ct = ContentType.objects.get_for_model(model)
        perms = Permission.objects.filter(content_type=ct)
        by_code = {p.codename: p for p in perms}
        out[model_name] = {
            "add": by_code.get(f"add_{model._meta.model_name}"),
            "change": by_code.get(f"change_{model._meta.model_name}"),
            "delete": by_code.get(f"delete_{model._meta.model_name}"),
            "view": by_code.get(f"view_{model._meta.model_name}"),
        }
    return out


def _ensure_group(name: str) -> Group:
    g, _ = Group.objects.get_or_create(name=name)
    return g


def _assign_group_perms() -> None:
    perms = _get_perms_for_models(MODEL_NAMES)
    g_mgr = _ensure_group(GROUP_MANAGER)
    g_tech = _ensure_group(GROUP_TECH)
    g_obs = _ensure_group(GROUP_OBS)

    # Manager -> tüm izinler
    for m in MODEL_NAMES:
        for key in ("add", "change", "delete", "view"):
            p = perms[m][key]
            if p:
                g_mgr.permissions.add(p)

    # Technician
    #   - Record: add/change/view
    #   - Asset : view
    rec = "CalibrationRecord"
    asset = "CalibrationAsset"
    for key in ("add", "change", "view"):
        p = perms[rec][key]
        if p:
            g_tech.permissions.add(p)
    if perms[asset]["view"]:
        g_tech.permissions.add(perms[asset]["view"])

    # Observer -> yalnız view
    for m in MODEL_NAMES:
        p = perms[m]["view"]
        if p:
            g_obs.permissions.add(p)


def _parse_map(s: str) -> Dict[str, str]:
    """
    'user1=mail1;user2=mail2' -> {'user1':'mail1', 'user2':'mail2'}
    """
    out: Dict[str, str] = {}
    if not s:
        return out
    parts = [x.strip() for x in s.split(";") if x.strip()]
    for part in parts:
        if "=" in part:
            u, e = part.split("=", 1)
            u = u.strip()
            e = e.strip()
            if u and e:
                out[u] = e
    return out


class Command(BaseCommand):
    help = (
        "Bakım/kalibrasyon rol ve izinlerini kurar, kullanıcıları gruplara ekler.\n"
        "Örnekler:\n"
        "  python manage.py setup_maintenance_roles --add-superusers --settings=core.settings_maintenance\n"
        "  python manage.py setup_maintenance_roles --usernames admin --emails \"admin=admin@local\" --settings=core.settings_maintenance\n"
        "  python manage.py setup_maintenance_roles --usernames admin,u1 --ensure-email default@local --settings=core.settings_maintenance\n"
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--add-superusers",
            action="store_true",
            help="Tüm süper kullanıcıları 'Bakım Yöneticisi' grubuna ekler.",
        )
        parser.add_argument(
            "--usernames",
            type=str,
            default="",
            help="Virgül ile kullanıcı adları (örn: admin,u1,u2) -> 'Bakım Yöneticisi'ne ekler.",
        )
        parser.add_argument(
            "--emails",
            type=str,
            default="",
            help="Kullanıcı e-postaları; format: user1=mail1;user2=mail2",
        )
        parser.add_argument(
            "--ensure-email",
            type=str,
            default="",
            help="E-postası boş olanları bu adrese ayarlar (tek adres).",
        )

    def handle(self, *args, **opts):
        self.stdout.write(self.style.NOTICE("Gruplar ve izinler oluşturuluyor..."))
        _assign_group_perms()

        U = get_user_model()
        usernames: List[str] = []
        if opts["usernames"]:
            usernames = [u.strip() for u in opts["usernames"].split(",") if u.strip()]

        email_map = _parse_map(opts["emails"])
        ensure_email = (opts["ensure_email"] or "").strip()

        targets: Set[int] = set()

        if opts["add_superusers"]:
            for u in U.objects.filter(is_superuser=True, is_active=True):
                targets.add(u.id)

        for uname in usernames:
            try:
                u = U.objects.get(username=uname)
                targets.add(u.id)
            except U.DoesNotExist:
                self.stderr.write(self.style.WARNING(f"Kullanıcı yok: {uname}"))

        if not targets:
            self.stdout.write(self.style.WARNING("Hedef kullanıcı bulunamadı (bayraklarla belirtin)."))

        g_mgr = Group.objects.get(name=GROUP_MANAGER)

        added = 0
        for u in U.objects.filter(id__in=list(targets)):
            # e-posta ayarla
            if u.username in email_map:
                u.email = email_map[u.username]
                u.save(update_fields=["email"])
            elif not u.email and ensure_email:
                u.email = ensure_email
                u.save(update_fields=["email"])

            u.groups.add(g_mgr)
            added += 1
            self.stdout.write(f"OK: {u.username} -> {GROUP_MANAGER} (email={u.email or '-'})")

        self.stdout.write(self.style.SUCCESS(f"Tamamlandı. Grup atanan kullanıcı sayısı: {added}"))
# <<< BLOK SONU: ID:PY-COM-4VYASZQ2
