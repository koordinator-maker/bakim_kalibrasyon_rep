from django.core.management.base import BaseCommand
from django.db import transaction
from maintenance.models import Equipment

MAX_LEN = 120
SUFFIX_DUP = "__DUP__{id}"
SUFFIX_EMPTY = "__EMPTY__{id}"

def _safe_unique_value(original: str, suffix: str) -> str:
    base = (original or "")
    room = MAX_LEN - len(suffix)
    base = base[:room] if room > 0 else ""
    return (base + suffix)[:MAX_LEN]

class Command(BaseCommand):
    help = "Finds duplicate/empty Equipment.serial_number values and makes them unique by appending a suffix. "\
           "Run with --commit to apply changes."

    def add_arguments(self, parser):
        parser.add_argument("--commit", action="store_true", help="Apply changes (otherwise dry-run).")

    def handle(self, *args, **opts):
        # Grupla (case-insensitive), boşlar tek grupta
        by_norm = {}
        qs = Equipment.objects.all().order_by("id")
        for e in qs:
            s = (e.serial_number or "")
            norm = s.strip().lower()
            key = norm if norm else "__EMPTY__"
            by_norm.setdefault(key, []).append((e.id, s))

        dupe_groups = {k: v for k, v in by_norm.items() if len(v) > 1}
        self.stdout.write(f"Duplicate groups: {len(dupe_groups)}")

        changes = []
        for key, rows in dupe_groups.items():
            # ilki korunur
            keeper_id, keeper_val = rows[0]
            for (pk, val) in rows[1:]:
                if key == "__EMPTY__":
                    new_val = _safe_unique_value("", SUFFIX_EMPTY.format(id=pk))
                else:
                    new_val = _safe_unique_value(val, SUFFIX_DUP.format(id=pk))
                # çakışma kontrolü
                if Equipment.objects.filter(serial_number=new_val).exclude(pk=pk).exists():
                    new_val = _safe_unique_value(val, SUFFIX_DUP.format(id=pk) + "_X")
                changes.append((pk, val, new_val))

        self.stdout.write(f"Rows to change: {len(changes)}")
        if not opts["commit"]:
            for pk, old, new in changes[:20]:
                self.stdout.write(f" [dry-run] id={pk} '{old}' -> '{new}'")
            if len(changes) > 20:
                self.stdout.write(f" ...(+{len(changes)-20} more)")
            self.stdout.write(self.style.WARNING("Dry-run complete. Use --commit to apply."))
            return

        # commit
        with transaction.atomic():
            for pk, old, new in changes:
                Equipment.objects.filter(pk=pk).update(serial_number=new)
        self.stdout.write(self.style.SUCCESS(f"Applied {len(changes)} updates."))