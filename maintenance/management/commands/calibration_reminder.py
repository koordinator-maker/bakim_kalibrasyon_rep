# REV: 1.1 | 2025-09-25 | Hash: 5806a8a8 | Parça: 1/1
# >>> BLOK: IMPORTS | Temel importlar | ID:PY-IMP-E8P0MXWW
# -*- coding: utf-8 -*-
from __future__ import annotations

# <<< BLOK SONU: ID:PY-IMP-E8P0MXWW
# >>> BLOK: COMMAND | Komut | ID:PY-COM-773MBFDD
from datetime import date, timedelta
from typing import Iterable, List, Set, Dict, Any
from pathlib import Path
import unicodedata

from django.conf import settings
from django.contrib.auth.models import Group, User
from django.core.mail import EmailMessage
from django.core.management.base import BaseCommand
from django.db.models import DateField, OuterRef, Subquery, Q

from maintenance.models import CalibrationAsset, CalibrationRecord


def _uniq_emails(items: Iterable[str]) -> List[str]:
    seen: Set[str] = set()
    out: List[str] = []
    for x in items:
        x = (x or "").strip()
        if x and x not in seen:
            seen.add(x)
            out.append(x)
    return out


def _maybe_fix_mojibake(s: str) -> str:
    """
    PS/CP1252 mojibake (örn. 'BakÄ±m YÃ¶neticisi') için latin-1 -> utf-8 geri çevirme dener.
    Zararsızdır; başarısız olursa orijinali döndürür.
    """
    try:
        if any(ch in s for ch in ("Ã", "Ä", "Ð", "Þ")):
            return s.encode("latin-1", errors="ignore").decode("utf-8", errors="ignore")
    except Exception:
        pass
    return s


def _norm(s: str) -> str:
    """
    Aksan/noktalama farklarına dayanıklı karşılaştırma için normalize string.
    - casefold
    - NFKD + diakritik temizleme
    """
    s = (s or "").strip().casefold()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    return s


def _collect_assets(days_list: List[int]) -> Dict[int, List[Dict[str, Any]]]:
    """days_list'e göre kovalar halinde cihaz listesini döndürür."""
    today = date.today()
    max_day = max(days_list)
    until = today + timedelta(days=max_day)

    latest_next = CalibrationRecord.objects.filter(
        asset_id=OuterRef("pk")
    ).order_by("-next_calibration").values("next_calibration")[:1]

    assets = (
        CalibrationAsset.objects.filter(is_active=True)
        .annotate(next_cal=Subquery(latest_next, output_field=DateField()))
        .filter(next_cal__isnull=False, next_cal__gte=today, next_cal__lte=until)
        .order_by("asset_code")
        .values(
            "id",
            "asset_code", "asset_name", "location",
            "brand", "model", "serial_no",
            "measure_range", "resolution", "unit",
            "accuracy", "uncertainty",
            "acceptance_criteria", "calibration_method",
            "standard_device", "standard_id",
            "owner", "responsible_email",
            "next_cal",
        )
    )

    buckets: Dict[int, List[Dict[str, Any]]] = {d: [] for d in days_list}
    for a in assets:
        remain = (a["next_cal"] - today).days
        chosen = None
        for d in days_list:
            if remain <= d:
                chosen = d
                break
        if chosen is None:
            chosen = max_day
        a = dict(a)
        a["days_remaining"] = remain
        a["window"] = chosen
        buckets[chosen].append(a)
    return buckets


def _compose_body(days_list: List[int], buckets: Dict[int, List[Dict[str, Any]]]) -> str:
    today = date.today()
    lines: List[str] = []
    lines.append(f"📅 Tarih: {today.strftime('%d.%m.%Y')}")
    lines.append(f"🎯 Pencereler: {', '.join(str(d) for d in days_list)} gün")
    lines.append("")
    total = 0
    for d in days_list:
        rows = buckets.get(d, [])
        if not rows:
            continue
        total += len(rows)
        lines.append(f"== {d} gün içinde ({len(rows)} cihaz) ==")
        for a in rows:
            lines.append(
                f"- {a['asset_code']} | {a['asset_name']} | {a.get('location','')} | "
                f"Kalibrasyon: {a['next_cal'].strftime('%d.%m.%Y')} (kalan {a['days_remaining']} g)"
            )
        lines.append("")
    if total == 0:
        lines.append("Bu pencerelerde yaklaşan kalibrasyon bulunmadı.")
    return "\n".join(lines)


def _write_csv(rows: List[Dict[str, Any]], path: Path) -> None:
    import csv
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([
            "window_days", "days_remaining", "asset_code", "asset_name", "location",
            "brand", "model", "serial_no", "measure_range", "resolution", "unit",
            "accuracy", "uncertainty", "acceptance_criteria", "calibration_method",
            "standard_device", "standard_id", "owner", "responsible_email", "next_calibration",
        ])
        for a in rows:
            w.writerow([
                a.get("window", ""),
                a.get("days_remaining", ""),
                a.get("asset_code", ""),
                a.get("asset_name", ""),
                a.get("location", ""),
                a.get("brand", ""),
                a.get("model", ""),
                a.get("serial_no", ""),
                a.get("measure_range", ""),
                a.get("resolution", ""),
                a.get("unit", ""),
                a.get("accuracy", ""),
                a.get("uncertainty", ""),
                a.get("acceptance_criteria", ""),
                a.get("calibration_method", ""),
                a.get("standard_device", ""),
                a.get("standard_id", ""),
                a.get("owner", ""),
                a.get("responsible_email", ""),
                a.get("next_cal").strftime("%Y-%m-%d") if a.get("next_cal") else "",
            ])


def _write_xlsx(rows: List[Dict[str, Any]], path: Path) -> None:
    try:
        import openpyxl  # type: ignore
    except Exception as ex:
        raise RuntimeError("XLSX için 'openpyxl' gerekli (pip install openpyxl)") from ex

    path.parent.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Yaklaşan Kalibrasyonlar"
    headers = [
        "window_days", "days_remaining", "asset_code", "asset_name", "location",
        "brand", "model", "serial_no", "measure_range", "resolution", "unit",
        "accuracy", "uncertainty", "acceptance_criteria", "calibration_method",
        "standard_device", "standard_id", "owner", "responsible_email", "next_calibration",
    ]
    ws.append(headers)
    for a in rows:
        ws.append([
            a.get("window", ""),
            a.get("days_remaining", ""),
            a.get("asset_code", ""),
            a.get("asset_name", ""),
            a.get("location", ""),
            a.get("brand", ""),
            a.get("model", ""),
            a.get("serial_no", ""),
            a.get("measure_range", ""),
            a.get("resolution", ""),
            a.get("unit", ""),
            a.get("accuracy", ""),
            a.get("uncertainty", ""),
            a.get("acceptance_criteria", ""),
            a.get("calibration_method", ""),
            a.get("standard_device", ""),
            a.get("standard_id", ""),
            a.get("owner", ""),
            a.get("responsible_email", ""),
            a.get("next_cal").strftime("%Y-%m-%d") if a.get("next_cal") else "",
        ])
    wb.save(str(path))


class Command(BaseCommand):
    help = (
        "Yaklaşan kalibrasyonlar için rol bazlı e-posta hatırlatması gönderir.\n"
        "Örnekler:\n"
        "  python manage.py calibration_reminder --days 30\n"
        "  python manage.py calibration_reminder --days 30 60 90 --roles \"Bakım Yöneticisi,Teknisyen\"\n"
        "  python manage.py calibration_reminder --days 14 --roles \"Bakım Yöneticisi\" --dry-run\n"
        "Ekler:\n"
        "  --attach csv | xlsx | both\n"
        "  --outdir var/calibration_reminders\n"
        "  --no-asset-emails  (yalnızca rol e-postalarına gönder)\n"
    )

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, nargs="+", default=[30],
                            help="Hatırlatma pencereleri (gün). Örn: 30 60 90")
        parser.add_argument("--roles", type=str, default="Bakım Yöneticisi",
                            help="Virgül ile ayrılmış grup adları. Örn: 'Bakım Yöneticisi,Teknisyen'")
        parser.add_argument("--attach", type=str, choices=["csv", "xlsx", "both"], default="csv",
                            help="Eklenecek dosya formatı.")
        parser.add_argument("--outdir", type=str, default="var/calibration_reminders",
                            help="Eklerin yazılacağı dizin (tarih alt klasörü otomatik eklenir).")
        parser.add_argument("--no-asset-emails", action="store_true",
                            help="Asset üzerindeki 'responsible_email' adreslerini alıcılara ekleme.")
        parser.add_argument("--dry-run", action="store_true",
                            help="E-posta göndermeden yalnızca özet yazdır.")

    def handle(self, *args, **opts):
        days_list: List[int] = sorted(set([d for d in opts["days"] if d > 0])) or [30]

        # --- ROLLERİ SAĞLAM ÇÖZ ---
        roles_input = (opts.get("roles") or "").strip()
        raw_parts = [p.strip() for p in roles_input.split(",") if p.strip()]
        fix_parts = [_maybe_fix_mojibake(p) for p in raw_parts]

        groups: List[Group] = []
        chosen_names: List[str] = []
        all_groups = list(Group.objects.all())
        norm_map = { _norm(g.name): g for g in all_groups }

        for raw, fixed in zip(raw_parts, fix_parts):
            # 1) Doğrudan iexact
            qs = Group.objects.filter(name__iexact=fixed)
            if qs.exists():
                g = qs.first()
                groups.append(g)  # type: ignore
                chosen_names.append(g.name)  # type: ignore
                continue
            if fixed != raw:
                qs2 = Group.objects.filter(name__iexact=raw)
                if qs2.exists():
                    g = qs2.first()
                    groups.append(g)  # type: ignore
                    chosen_names.append(g.name)  # type: ignore
                    continue
            # 2) Normalize fallback
            cand = norm_map.get(_norm(fixed)) or norm_map.get(_norm(raw))
            if cand:
                groups.append(cand)
                chosen_names.append(cand.name)
                continue

        # Tekilleştir
        seen_ids: Set[int] = set()
        uniq_groups: List[Group] = []
        uniq_names: List[str] = []
        for g, n in zip(groups, chosen_names):
            if g.id not in seen_ids:
                seen_ids.add(g.id)
                uniq_groups.append(g)
                uniq_names.append(n)

        attach_mode: str = opts["attach"]
        outdir = Path(opts["outdir"])
        dry_run: bool = bool(opts["dry_run"])
        skip_asset_emails: bool = bool(opts["no_asset_emails"])

        today = date.today()

        # Veriyi topla
        buckets = _collect_assets(days_list)
        all_rows: List[Dict[str, Any]] = []
        for d in days_list:
            all_rows.extend(buckets.get(d, []))

        # Alıcılar
        role_emails: List[str] = []
        if uniq_groups:
            qs = User.objects.filter(groups__in=uniq_groups, is_active=True).values_list("email", flat=True)
            role_emails = [e for e in qs if e]
        else:
            existing = [g.name for g in all_groups]
            self.stderr.write(self.style.WARNING(
                f"Hiç grup bulunamadı. İstenen roller: {raw_parts or ['(boş)']}. "
                f"Mevcut gruplar: {existing or ['(yok)']}"
            ))

        asset_emails: List[str] = []
        if not skip_asset_emails:
            asset_emails = [a.get("responsible_email") for a in all_rows if a.get("responsible_email")]

        recipients = _uniq_emails(role_emails + asset_emails)

        # Gövde / konu
        body = _compose_body(days_list, buckets)
        subject = f"[Kalibrasyon Hatırlatma] {today.strftime('%d.%m.%Y')} – {len(all_rows)} cihaz"
        from_email = getattr(settings, "DEFAULT_FROM_EMAIL", "no-reply@localhost")

        # Ek dosyalar
        attachments: List[Path] = []
        dated_dir = outdir / today.strftime("%Y%m%d")
        try:
            if all_rows:
                if attach_mode in ("csv", "both"):
                    csv_path = dated_dir / f"kalibrasyon_{today.strftime('%Y%m%d')}.csv"
                    _write_csv(all_rows, csv_path)
                    attachments.append(csv_path)
                if attach_mode in ("xlsx", "both"):
                    xlsx_path = dated_dir / f"kalibrasyon_{today.strftime('%Y%m%d')}.xlsx"
                    _write_xlsx(all_rows, xlsx_path)
                    attachments.append(xlsx_path)
        except Exception as ex:
            self.stderr.write(self.style.WARNING(f"Ek dosya üretimi hatalı: {ex} (ekler olmadan devam ediliyor)"))
            attachments = []

        # Bilgi logları
        self.stdout.write(self.style.NOTICE(f"Çözümlenen roller: {uniq_names or ['(yok)']}"))
        self.stdout.write(self.style.NOTICE(f"Alıcı sayısı: {len(recipients)}"))
        self.stdout.write(self.style.NOTICE(f"Kayıt sayısı: {len(all_rows)}"))
        if attachments:
            self.stdout.write(self.style.NOTICE("Ekler:"))
            for p in attachments:
                self.stdout.write(f" - {p}")

        if dry_run or not recipients:
            self.stdout.write("---- ÖNİZLEME (dry-run) ----")
            self.stdout.write(f"Kime: {', '.join(recipients) if recipients else '(alıcı yok)'}")
            self.stdout.write(f"Konu: {subject}")
            self.stdout.write(body)
            if attachments:
                self.stdout.write("(Not: Ekler üretilmiştir; e-posta gönderilmedi.)")
            self.stdout.write("---- SON ----")
            return

        # E-posta gönderimi (eklerle)
        try:
            email = EmailMessage(subject=subject, body=body, from_email=from_email, to=recipients)
            for p in attachments:
                if p.suffix.lower() == ".csv":
                    email.attach(p.name, p.read_bytes(), "text/csv")
                elif p.suffix.lower() == ".xlsx":
                    email.attach(p.name, p.read_bytes(),
                                 "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                else:
                    email.attach(p.name, p.read_bytes(), "application/octet-stream")
            sent = email.send(fail_silently=False)
            self.stdout.write(self.style.SUCCESS(f"E-posta gönderildi (adet={sent})."))
        except Exception as ex:
            self.stderr.write(self.style.ERROR(f"E-posta gönderimi başarısız: {ex}"))
            self.stderr.write("İçerik aşağıdadır (gönderilmedi):")
            self.stderr.write(body)
# <<< BLOK SONU: ID:PY-COM-773MBFDD
