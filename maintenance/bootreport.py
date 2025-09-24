# REV: 1.0 | 2025-09-24 | Hash: f86d901c | Parça: 1/1
# -*- coding: utf-8 -*-
from __future__ import annotations

import json
import os
import platform
import sys
import hashlib
import shutil
import glob
from datetime import datetime
from typing import Any, Dict, List

import django
from django.conf import settings
from django.apps import apps as dj_apps
from django.urls import get_resolver, URLPattern, URLResolver
from django.contrib.auth import get_user_model


def safe_write_boot_report() -> None:
    """
    Açılışta güvenli şekilde rapor üretir ve var/ içine yazar.
    - JSON & TXT dosyalarını OLUŞTURUR/GÜNCELLER.
    - Yazmadan ÖNCE mevcut dosyaları timestamp'li şekilde AYNI klasöre YEDEKLER.
    - Eski yedekleri (varsayılan 20 adetten fazlasını) siler.
    BOOTREPORT_DEBUG=1 ise istisna detaylarını stdout'a basar.
    """
    try:
        data = _collect_boot_data()
        _write_files(data)
    except Exception as e:
        if os.environ.get("BOOTREPORT_DEBUG") == "1" or bool(getattr(settings, "DEBUG", False)):
            try:
                import traceback
                print("[bootreport] ERROR:", repr(e))
                traceback.print_exc()
            except Exception:
                pass
        # Sessizce geç
        return


def _collect_boot_data() -> Dict[str, Any]:
    now = datetime.now()
    base_dir = str(getattr(settings, "BASE_DIR", os.getcwd()))

    info: Dict[str, Any] = {
        "generated_at": now.isoformat(timespec="seconds"),
        "tz": str(getattr(settings, "TIME_ZONE", "")),
        "python": {
            "version": sys.version,
            "implementation": platform.python_implementation(),
        },
        "django": {
            "version": django.get_version(),
            "debug": bool(getattr(settings, "DEBUG", False)),
        },
        "project": {
            "base_dir": base_dir,
            "root_urlconf": getattr(settings, "ROOT_URLCONF", ""),
            "allowed_hosts": list(getattr(settings, "ALLOWED_HOSTS", [])),
            "secret_key_masked": _mask(getattr(settings, "SECRET_KEY", "")),
            "language_code": getattr(settings, "LANGUAGE_CODE", ""),
            "use_tz": bool(getattr(settings, "USE_TZ", True)),
        },
        "paths": {
            "static_url": getattr(settings, "STATIC_URL", ""),
            "static_root": str(getattr(settings, "STATIC_ROOT", "")),
            "staticfiles_dirs": [str(p) for p in getattr(settings, "STATICFILES_DIRS", []) or []],
            "media_url": getattr(settings, "MEDIA_URL", ""),
            "media_root": str(getattr(settings, "MEDIA_ROOT", "")),
            "template_dirs": _template_dirs(),
        },
        "apps": {
            "installed_apps": [str(x) for x in getattr(settings, "INSTALLED_APPS", [])],
            "middleware": [str(x) for x in getattr(settings, "MIDDLEWARE", [])],
            "auth_user_model": _user_model_path(),
        },
        "database": _db_summary(),
        "urls": _list_all_urls(),
        "models": _introspect_models(),
        "hr_lms_focus": _hr_lms_focus_section(),
        "signature": {},
    }

    # İmza — tüm değerleri JSON-uyumlu hale getir
    sig_payload = {
        "installed_apps": [str(x) for x in info["apps"]["installed_apps"]],
        "middleware": [str(x) for x in info["apps"]["middleware"]],
        "database": {k: {kk: str(vv) for kk, vv in info["database"][k].items()} for k in info["database"]},
        "urls": [str(u.get("route", "")) for u in info["urls"]],
        "models": {m["model_label"]: [str(f["name"]) for f in m["fields"]] for m in info["models"]},
    }
    signature_src = json.dumps(sig_payload, ensure_ascii=False, sort_keys=True, default=str).encode("utf-8")
    info["signature"] = {
        "sha256": hashlib.sha256(signature_src).hexdigest(),
        "short": hashlib.sha256(signature_src).hexdigest()[:12],
    }
    return info


def _mask(value: str, keep: int = 6) -> str:
    if not value:
        return ""
    if len(value) <= keep:
        return "*" * len(value)
    return value[:keep] + "*" * (len(value) - keep)


def _template_dirs() -> List[str]:
    dirs: List[str] = []
    for cfg in getattr(settings, "TEMPLATES", []):
        for d in cfg.get("DIRS", []):
            dirs.append(str(d))
    return dirs


def _db_summary() -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    dbs = getattr(settings, "DATABASES", {})
    for alias, cfg in dbs.items():
        # Path nesneleri dahil tümünü stringe zorla
        engine = str(cfg.get("ENGINE", ""))
        name = str(cfg.get("NAME", ""))
        out[alias] = {"engine": engine, "name": name}
    return out


def _user_model_path() -> str:
    try:
        User = get_user_model()
        return f"{User._meta.app_label}.{User.__name__}"
    except Exception:
        return ""


def _list_all_urls() -> List[Dict[str, Any]]:
    resolver = get_resolver()
    flat: List[Dict[str, Any]] = []

    def _walk(patterns, prefix=""):
        for p in patterns:
            if isinstance(p, URLPattern):
                route = str(p.pattern)
                name = p.name
                callback = getattr(p.callback, "__module__", "") + "." + getattr(p.callback, "__name__", "")
                flat.append({"route": prefix + route, "name": name, "callback": callback})
            elif isinstance(p, URLResolver):
                route = str(p.pattern)
                _walk(p.url_patterns, prefix + route)
            else:
                flat.append({"route": str(p.pattern), "name": getattr(p, "name", None), "callback": ""})

    _walk(resolver.url_patterns)
    return flat


def _introspect_models() -> List[Dict[str, Any]]:
    models_info: List[Dict[str, Any]] = []
    for model in dj_apps.get_models():
        try:
            fields = []
            for f in model._meta.get_fields():
                field_info = {
                    "name": f.name,
                    "type": f.__class__.__name__,
                    "is_relation": f.is_relation,
                    "many_to_many": getattr(f, "many_to_many", False),
                    "related_model": f.related_model._meta.label if getattr(f, "related_model", None) else None,
                }
                for attr in ("null", "blank", "db_index", "primary_key", "unique", "choices"):
                    if hasattr(f, attr):
                        val = getattr(f, attr)
                        if attr == "choices" and val:
                            try:
                                val = [str(c[0]) for c in val]
                            except Exception:
                                val = str(val)
                        field_info[attr] = val
                fields.append(field_info)

            models_info.append(
                {
                    "app_label": model._meta.app_label,
                    "model_name": model.__name__,
                    "model_label": model._meta.label,
                    "db_table": model._meta.db_table,
                    "fields": fields,
                }
            )
        except Exception:
            continue
    models_info.sort(key=lambda m: m["model_label"])
    return models_info


def _hr_lms_focus_section() -> Dict[str, Any]:
    out: Dict[str, Any] = {"training_plan": None, "training_plan_attendee": None}
    try:
        TP = dj_apps.get_model("trainings", "TrainingPlan")
    except Exception:
        TP = None
    if TP:
        out["training_plan"] = {"model_label": TP._meta.label, "fields": [f.name for f in TP._meta.get_fields()]}
    try:
        TPA = dj_apps.get_model("trainings", "TrainingPlanAttendee")
    except Exception:
        TPA = None
    if TPA:
        out["training_plan_attendee"] = {"model_label": TPA._meta.label, "fields": [f.name for f in TPA._meta.get_fields()]}
    return out


def _write_files(data: Dict[str, Any]) -> None:
    """
    - var/ klasörünü garanti oluşturur
    - Mevcut JSON/TXT dosyalarını timestamp'li .bak olarak yedekler
    - Yeni içerikleri yazar
    - Yedekleri sınırlar (KEEP=20)
    """
    base_dir = str(getattr(settings, "BASE_DIR", os.getcwd()))
    var_dir = os.path.join(base_dir, "var")
    os.makedirs(var_dir, exist_ok=True)

    json_path = os.path.join(var_dir, "bootreport.json")
    txt_path  = os.path.join(var_dir, "bootreport.txt")

    # Önce yedekle
    _backup_existing(json_path, keep=int(os.environ.get("BOOTREPORT_KEEP", "20")))
    _backup_existing(txt_path,  keep=int(os.environ.get("BOOTREPORT_KEEP", "20")))

    # Sonra yaz
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)

    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(_summarize(data))


def _backup_existing(path: str, keep: int = 20) -> None:
    """
    path mevcutsa, aynı klasöre `<name>.<YYYYmmdd-HHMMSS><ext>.bak` kopyası oluştur.
    Ardından aynı pattern'deki en yeni keep adet dışındakileri sil.
    """
    if not os.path.exists(path):
        return
    d = os.path.dirname(path)
    base = os.path.basename(path)
    name, ext = os.path.splitext(base)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak_name = f"{name}.{ts}{ext}.bak"
    bak_path = os.path.join(d, bak_name)

    try:
        shutil.copy2(path, bak_path)
    except Exception as e:
        if os.environ.get("BOOTREPORT_DEBUG") == "1":
            print(f"[bootreport] BACKUP COPY ERROR for {path} -> {e!r}")

    # Retention: aynı isim için üretilmiş yedekleri bul ve sınırla
    pattern = os.path.join(d, f"{name}.*{ext}.bak")
    backups = sorted(glob.glob(pattern), reverse=True)  # en yeni başta
    if len(backups) > keep:
        for old in backups[keep:]:
            try:
                os.remove(old)
            except Exception as e:
                if os.environ.get("BOOTREPORT_DEBUG") == "1":
                    print(f"[bootreport] BACKUP PRUNE ERROR for {old} -> {e!r}")


def _summarize(d: Dict[str, Any]) -> str:
    lines: List[str] = []
    push = lines.append

    push(f"Generated: {d.get('generated_at')}  TZ={d.get('tz')}")
    py = d.get("python", {}).get("version", "")
    push(f"Python: {d.get('python', {}).get('implementation','')} {py.split()[0] if py else ''}")
    push(f"Django: {d.get('django', {}).get('version','')}  DEBUG={d.get('django', {}).get('debug')}")
    proj = d.get("project", {})
    push(f"Project: BASE_DIR={proj.get('base_dir','')}  ROOT_URLCONF={proj.get('root_urlconf','')}")
    push(f"Paths: STATIC_ROOT={d.get('paths',{}).get('static_root','')}  MEDIA_ROOT={d.get('paths',{}).get('media_root','')}")
    tdirs = d.get("paths", {}).get("template_dirs", []) or []
    push(f"Templates: {', '.join(tdirs) or '-'}")
    push(f"Auth User Model: {d.get('apps',{}).get('auth_user_model','')}")
    push(f"Installed Apps: {len(d.get('apps',{}).get('installed_apps', []))} items")
    push(f"Middleware   : {len(d.get('apps',{}).get('middleware', []))} items")
    push("Databases:")
    for alias, cfg in (d.get("database") or {}).items():
        push(f"  - {alias}: {cfg.get('engine','')}  name={cfg.get('name','')}")
    urls = d.get("urls") or []
    push(f"URL Patterns: {len(urls)} items")
    for u in urls[:50]:
        nm = u.get("name") or "-"
        push(f"  - {u.get('route','')}  (name={nm})")
    if len(urls) > 50:
        push(f"  ... (+{len(urls)-50} more)")

    hl = d.get("hr_lms_focus", {})
    tp = hl.get("training_plan")
    tpa = hl.get("training_plan_attendee")
    push("HR-LMS Focus:")
    if tp:
        push(f"  TrainingPlan: {tp['model_label']}  fields={', '.join(tp['fields'])}")
    else:
        push("  TrainingPlan: -")
    if tpa:
        push(f"  TrainingPlanAttendee: {tpa['model_label']}  fields={', '.join(tpa['fields'])}")
    else:
        push("  TrainingPlanAttendee: -")

    sig = d.get("signature", {})
    push(f"Signature: sha256={sig.get('sha256','')[:12]}…  short={sig.get('short','')}")

    return "\n".join(lines)
