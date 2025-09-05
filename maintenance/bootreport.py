# YENİ DOSYA: maintenance/bootreport.py
from __future__ import annotations
import json, os, platform, sys, hashlib
from datetime import datetime
from typing import Any, Dict, List
import django
from django.conf import settings
from django.apps import apps as dj_apps
from django.urls import get_resolver, URLPattern, URLResolver
from django.contrib.auth import get_user_model

def safe_write_boot_report() -> None:
    """Uygulama açılışında çağrılır; hata çıkarsa sessizce düşer."""
    try:
        data = _collect_boot_data()
        _write_files(data)
    except Exception:
        return

def _collect_boot_data() -> Dict[str, Any]:
    now = datetime.now()
    base_dir = str(getattr(settings, "BASE_DIR", os.getcwd()))
    info: Dict[str, Any] = {
        "generated_at": now.isoformat(timespec="seconds"),
        "tz": str(getattr(settings, "TIME_ZONE", "")),
        "python": {"version": sys.version, "implementation": platform.python_implementation()},
        "django": {"version": django.get_version(), "debug": bool(getattr(settings, "DEBUG", False))},
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
            "installed_apps": list(getattr(settings, "INSTALLED_APPS", [])),
            "middleware": list(getattr(settings, "MIDDLEWARE", [])),
            "auth_user_model": _user_model_path(),
        },
        "database": _db_summary(),
        "urls": _list_all_urls(),
        "models": _introspect_models(),
        "signature": {},
    }
    signature_src = json.dumps(
        {
            "installed_apps": info["apps"]["installed_apps"],
            "middleware": info["apps"]["middleware"],
            "database": info["database"],
            "urls": [u["route"] for u in info["urls"]],
            "models": {m["model_label"]: [f["name"] for f in m["fields"]] for m in info["models"]},
        },
        ensure_ascii=False, sort_keys=True
    ).encode("utf-8")
    digest = hashlib.sha256(signature_src).hexdigest()
    info["signature"] = {"sha256": digest, "short": digest[:12]}
    return info

def _mask(v: str, keep: int = 6) -> str:
    if not v:
        return ""
    return v[:keep] + "*" * max(0, len(v) - keep)

def _template_dirs() -> List[str]:
    dirs: List[str] = []
    for cfg in getattr(settings, "TEMPLATES", []):
        for d in cfg.get("DIRS", []):
            dirs.append(str(d))
    return dirs

def _db_summary() -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for alias, cfg in getattr(settings, "DATABASES", {}).items():
        out[alias] = {"engine": cfg.get("ENGINE", ""), "name": cfg.get("NAME", "")}
    return out

def _user_model_path() -> str:
    try:
        U = get_user_model()
        return f"{U._meta.app_label}.{U.__name__}"
    except Exception:
        return ""

def _list_all_urls() -> List[Dict[str, Any]]:
    resolver = get_resolver()
    flat: List[Dict[str, Any]] = []
    def walk(patterns, prefix=""):
        for p in patterns:
            if isinstance(p, URLPattern):
                route = str(p.pattern)
                name = p.name
                callback = getattr(p.callback, "__module__", "") + "." + getattr(p.callback, "__name__", "")
                flat.append({"route": prefix + route, "name": name, "callback": callback})
            elif isinstance(p, URLResolver):
                route = str(p.pattern)
                walk(p.url_patterns, prefix + route)
            else:
                flat.append({"route": str(p.pattern), "name": getattr(p, "name", None), "callback": ""})
    walk(resolver.url_patterns)
    return flat

def _introspect_models() -> List[Dict[str, Any]]:
    models_info: List[Dict[str, Any]] = []
    for model in dj_apps.get_models():
        try:
            fields = []
            for f in model._meta.get_fields():
                info = {
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
                        info[attr] = val
                fields.append(info)
            models_info.append({
                "app_label": model._meta.app_label,
                "model_name": model.__name__,
                "model_label": model._meta.label,
                "db_table": model._meta.db_table,
                "fields": fields,
            })
        except Exception:
            continue
    models_info.sort(key=lambda m: m["model_label"])
    return models_info

def _write_files(data: Dict[str, Any]) -> None:
    base_dir = str(getattr(settings, "BASE_DIR", os.getcwd()))
    var_dir = os.path.join(base_dir, "var")  # YENİ KLASÖR (runtime)
    os.makedirs(var_dir, exist_ok=True)
    with open(os.path.join(var_dir, "bootreport.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    with open(os.path.join(var_dir, "bootreport.txt"), "w", encoding="utf-8") as f:
        f.write(_summarize(data))

def _summarize(d):
    lines = []
    P = lines.append
    P(f"Generated: {d.get('generated_at')}  TZ={d.get('tz')}")
    P(f"Python: {d['python']['implementation']} {d['python']['version'].split()[0]}")
    P(f"Django: {d['django']['version']}  DEBUG={d['django']['debug']}")
    proj = d["project"]
    P(f"Project: BASE_DIR={proj['base_dir']}  ROOT_URLCONF={proj['root_urlconf']}")
    P(f"STATIC_ROOT={d['paths']['static_root']}  MEDIA_ROOT={d['paths']['media_root']}")
    P(f"Templates: {', '.join(d['paths']['template_dirs']) or '-'}")
    P(f"Auth User Model: {d['apps']['auth_user_model']}")
    P(f"Installed Apps: {len(d['apps']['installed_apps'])}  Middleware: {len(d['apps']['middleware'])}")
    P("Databases:")
    for alias, cfg in d["database"].items():
        P(f"  - {alias}: {cfg['engine']} name={cfg['name']}")
    P(f"URL Patterns: {len(d['urls'])} items")
    for u in d["urls"][:50]:
        nm = u["name"] or "-"
        P(f"  - {u['route']} (name={nm})")
    sig = d.get("signature", {})
    P(f"Signature: sha256={sig.get('sha256','')[:12]}…  short={sig.get('short','')}")
    return "\n".join(lines)
