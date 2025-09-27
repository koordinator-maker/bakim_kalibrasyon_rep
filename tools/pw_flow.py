# -*- coding: utf-8 -*-
import os, sys, json, time, re, pathlib
from contextlib import contextmanager
from typing import List, Tuple
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Error as PWError

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8010").rstrip("/")

def _abs_path(p: str) -> str:
    p = p.replace("\\", "/")
    root = pathlib.Path.cwd()
    full = (root / p).resolve()
    full.parent.mkdir(parents=True, exist_ok=True)
    return str(full)

def _resolve_url(arg: str) -> str:
    if arg.startswith("http://") or arg.startswith("https://"):
        return arg
    if not arg.startswith("/"):
        arg = "/" + arg
    return BASE_URL + arg

def _parse_line(line: str) -> Tuple[str, str]:
    line = line.strip()
    if not line or line.startswith("#"):
        return ("COMMENT", line)
    sp = line.split(None, 1)
    if len(sp) == 1:
        return (sp[0].upper(), "")
    return (sp[0].upper(), sp[1])

@contextmanager
def browser_ctx(headless: bool):
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=headless)
        context = browser.new_context()  # EPHEMERAL: her akış ayrı çerez/profil
        page = context.new_page()
        page.set_default_timeout(30_000)
        try:
            yield page, context, browser
        finally:
            try: context.close()
            except Exception: pass
            try: browser.close()
            except Exception: pass

def run_flow(steps: List[str], headless: bool=False) -> Tuple[bool, list]:
    results = []
    ok_all = True
    with browser_ctx(headless=headless) as (page, _ctx, _br):
        for i, raw in enumerate(steps, start=1):
            cmd, arg = _parse_line(raw)
            if cmd == "COMMENT":
                continue
            step_ok, err = True, None
            try:
                if cmd == "GOTO":
                    url = _resolve_url(arg.strip())
                    page.goto(url, wait_until="domcontentloaded")
                elif cmd == "WAIT":
                    a = arg.strip()
                    aU = a.upper()
                    if aU.startswith("SELECTOR "):
                        sel = a[len("SELECTOR "):].strip()
                        page.wait_for_selector(sel, state="visible")
                    elif aU.startswith("URL CONTAINS "):
                        needle = a[len("URL CONTAINS "):].strip()
                        deadline = time.time() + 30
                        while time.time() < deadline:
                            if needle in page.url:
                                break
                            time.sleep(0.1)
                        else:
                            raise PWTimeout(f'URL does not contain "{needle}"')
                    else:
                        raise PWError(f"Unsupported WAIT arg: {arg}")
                elif cmd == "FILL":
                    sp = arg.split(None, 1)
                    if len(sp) < 2:
                        raise PWError("FILL requires 'selector text'")
                    sel, txt = sp[0], sp[1]
                    page.fill(sel, txt)
                elif cmd == "CLICK":
                    sel = arg.strip()
                    page.click(sel)
                elif cmd == "SCREENSHOT":
                    path = _abs_path(arg.strip())
                    page.screenshot(path=path, full_page=False)
                elif cmd == "EXPECT":
                    a = arg.strip()
                    aU = a.upper()
                    if aU.startswith("URL CONTAINS "):
                        needle = a[len("URL CONTAINS "):].strip()
                        if needle not in page.url:
                            raise AssertionError(f"url does not contain {needle}")
                    else:
                        raise PWError(f"Unsupported EXPECT arg: {arg}")
                else:
                    raise PWError(f"Unknown cmd: {cmd}")
            except (PWTimeout, PWError, AssertionError) as e:
                step_ok, err = False, f"{e.__class__.__name__}: {str(e)}"
                ok_all = False
            results.append({
                "i": i, "cmd": cmd, "arg": arg,
                "ok": step_ok, "error": err,
                "url": page.url if page else "about:blank"
            })
            if not step_ok:
                break
    return ok_all, results

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--headful", action="store_true")
    args = ap.parse_args()

    # UTF-8-SIG: BOM varsa otomatik temizler
    text: str
    with open(args.steps, "r", encoding="utf-8-sig") as f:
        text = f.read()
    # Satırlara böl
    steps = text.splitlines()

    ok, res = run_flow(steps, headless=(not args.headful))
    out = {"ok": ok, "results": res}
    pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print("[PW-FLOW] " + ("PASSED" if ok else "FAILED"))
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
