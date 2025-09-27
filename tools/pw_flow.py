# -*- coding: utf-8 -*-
"""
tools/pw_flow.py — dayanıklı sürüm
- PWDEBUG'i zorla kapatır (inspector açılmasın)
- Chromium'u --no-sandbox/--disable-gpu ile açar
- İlk GOTO'da sayfa/bağlam kapanırsa tarayıcıyı komple yeniden kurar (2 deneme)
- Persistent context (kullanıcı profili) ile daha stabil çalışır
"""

from __future__ import annotations
import os, sys, json, time, re, pathlib
from typing import List, Tuple
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeoutError, Error as PWError

# Inspector'ı kesin kapat
os.environ.pop("PWDEBUG", None)

DEF_TIMEOUT = int(os.environ.get("PW_TIMEOUT_MS", "30000"))
BASE_URL    = os.environ.get("BASE_URL", "http://127.0.0.1:8010")
HEADLESS    = os.environ.get("PW_HEADLESS", "1").lower() not in ("0","false","no","off")

PROFILE_DIR = str(pathlib.Path("_otokodlama/pw_profile").resolve())

def _log(msg: str) -> None:
    print(msg, flush=True)

def _ensure_dirs(path: str) -> None:
    p = pathlib.Path(path)
    if p.parent and not p.parent.exists():
        p.parent.mkdir(parents=True, exist_ok=True)

def parse_flow(path: str) -> List[Tuple[str, str]]:
    steps: List[Tuple[str, str]] = []
    with open(path, "r", encoding="utf-8") as f:
        for raw in f.read().splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith(">>"):
                line = line[2:].strip()
                if not line:
                    continue
            m = re.match(r"^([A-Z]+)\s+(.*)$", line)
            if not m:
                continue
            steps.append((m.group(1).upper(), m.group(2).strip()))
    return steps

def _open_persistent_context(p, headless: bool):
    args = ["--disable-gpu", "--no-sandbox", "--disable-dev-shm-usage", "--no-first-run", "--no-default-browser-check"]
    ctx = p.chromium.launch_persistent_context(
        user_data_dir=PROFILE_DIR,
        headless=headless,
        args=args,
        ignore_https_errors=True,
        viewport=None,  # tam pencere
    )
    page = ctx.new_page()
    return ctx, page

def run_flow(base_url: str, steps: List[Tuple[str,str]], headless: bool=True,
             timeout_ms: int=DEF_TIMEOUT, retry_on_crash: int=1):

    results = []
    ok_all  = True

    _ensure_dirs(PROFILE_DIR)

    with sync_playwright() as p:
        context, page = _open_persistent_context(p, headless)

        def recover():
            nonlocal context, page
            try:
                if page and not page.is_closed():
                    page.close()
            except Exception:
                pass
            try:
                context.close()
            except Exception:
                pass
            time.sleep(0.25)
            context, page = _open_persistent_context(p, headless)
            time.sleep(0.25)

        for i, (cmd, arg) in enumerate(steps, 1):
            step_ok, err, url = True, None, None
            try:
                if cmd == "GOTO":
                    target = arg.strip()
                    if target.startswith("/"):
                        target = base_url.rstrip("/") + target
                    attempts = 0
                    while True:
                        try:
                            if page.is_closed():
                                page = context.new_page()
                            page.goto(target, wait_until="domcontentloaded", timeout=timeout_ms)
                            break
                        except PWError as e:
                            if attempts < retry_on_crash:
                                attempts += 1
                                _log(f"[RETRY] browser/page closed on GOTO -> recovering (attempt {attempts})")
                                recover()
                                continue
                            raise

                elif cmd == "WAIT":
                    if arg.upper().startswith("SELECTOR "):
                        sel = arg.split(" ",1)[1]
                        page.wait_for_selector(sel, timeout=timeout_ms)
                    elif arg.upper().startswith("URL CONTAINS "):
                        frag = arg.split(" ",2)[2]
                        page.wait_for_function("frag => window.location.href.includes(frag)", frag, timeout=timeout_ms)
                    else:
                        raise ValueError(f"WAIT arg not understood: {arg}")

                elif cmd == "FILL":
                    parts = arg.split(" ", 1)
                    if len(parts) != 2:
                        raise ValueError("FILL <selector> <value> beklenir")
                    sel, val = parts
                    page.fill(sel, val, timeout=timeout_ms)

                elif cmd == "CLICK":
                    sel = arg.strip()
                    page.click(sel, timeout=timeout_ms)

                elif cmd == "SCREENSHOT":
                    path = arg.strip()
                    _ensure_dirs(path)
                    page.screenshot(path=path, full_page=True)

                elif cmd == "EXPECT":
                    if arg.upper().startswith("URL CONTAINS "):
                        frag = arg.split(" ",2)[2]
                        if frag not in page.url:
                            raise AssertionError(f"url does not contain {frag}")
                    else:
                        raise ValueError(f"EXPECT arg not understood: {arg}")
                else:
                    _log(f"[WARN] Komut desteklenmiyor: {cmd} {arg}")

                url = page.url

            except Exception as e:
                step_ok = False
                err = f"{type(e).__name__}: {e}"
                try:
                    url = page.url
                except Exception:
                    url = "about:blank"

            results.append({"i": i, "cmd": cmd, "arg": arg, "ok": step_ok, "error": err, "url": url})
            if not step_ok:
                ok_all = False
                break

        try:
            context.close()
        except Exception:
            pass

    return ok_all, results

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", required=True)
    ap.add_argument("--out",   required=True)
    ap.add_argument("--headful", action="store_true")
    args = ap.parse_args()

    steps = parse_flow(args.steps)
    headless = not args.headful and HEADLESS

    ok, results = run_flow(BASE_URL, steps, headless=headless, timeout_ms=DEF_TIMEOUT, retry_on_crash=1)
    pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump({"ok": ok, "results": results}, f, ensure_ascii=False, indent=2)

    print("[PW-FLOW] " + ("PASSED" if ok else "FAILED"))
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
