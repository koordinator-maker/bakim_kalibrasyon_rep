#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# tools/pw_flow.py  (mini akÄ±ÅŸ koÅŸucu)

import sys, json, argparse, re, os, time
from pathlib import Path

def expand_env(text: str) -> str:
    return re.sub(r"\$\{(\w+)\}", lambda m: os.environ.get(m.group(1), ""), text)

def parse_steps(text: str):
    steps = []
    for raw in text.splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        m = re.match(r"(\w+)\s+(.*)", s)
        if not m:
            continue
        steps.append((m.group(1).upper(), m.group(2)))
    return steps

def run_flow(base_url, steps, headless=True, viewport=None, timeout_ms=15000):
    from playwright.sync_api import sync_playwright
    results, ok = [], True
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=headless)
        context = browser.new_context(viewport=viewport or {"width": 1280, "height": 800})
        page = context.new_page()
        for i, (cmd, arg) in enumerate(steps, 1):
            step_ok, err = True, None
            try:
                if cmd == "GOTO":
                    url = arg.strip()
                    if url.startswith("/"):
                        url = base_url.rstrip("/") + url
                    page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)
                elif cmd == "CLICK":
                    sel = arg.strip()
                    page.click(sel, timeout=timeout_ms)
                elif cmd == "FILL":
                    m = re.match(r"(\S+)\s+(.+)", arg)
                    if not m: raise ValueError("FILL <selector> <text>")
                    sel, val = m.groups()
                    page.fill(sel, val, timeout=timeout_ms)
                elif cmd == "WAIT":
                    a = arg.strip()
                    if a.upper().startswith("URL "):
                        cond = a[4:].strip()
                        if cond.lower().startswith("contains "):
                            expect = cond[9:].strip()
                            page.wait_for_url(lambda u: expect in u, timeout=timeout_ms)
                        else:
                            page.wait_for_url(cond, timeout=timeout_ms)
                    elif a.upper().startswith("SELECTOR "):
                        sel = a[9:].strip()
                        page.wait_for_selector(sel, timeout=timeout_ms)
                    elif a.upper().startswith("TIME "):
                        ms = int(a.split()[1]); time.sleep(ms/1000.0)
                elif cmd == "EXPECT":
                    a = arg.strip()
                    if a.upper().startswith("SELECTOR "):
                        rest = a[9:].strip()
                        m = re.match(r'(\S+)\s+"(.+)"', rest)
                        if not m: raise ValueError('EXPECT SELECTOR <sel> "text"')
                        sel, txt = m.groups()
                        el = page.locator(sel).first
                        el.wait_for(timeout=timeout_ms)
                        got = el.inner_text()
                        if txt not in got:
                            raise AssertionError(f'text "{txt}" not in "{got}"')
                    elif a.upper().startswith("URL CONTAINS "):
                        expect = a[13:].strip()
                        if expect not in page.url:
                            raise AssertionError(f'url does not contain {expect}')
                elif cmd == "SCREENSHOT":
                    path = arg.strip()
                    Path(path).parent.mkdir(parents=True, exist_ok=True)
                    page.screenshot(path=path, full_page=True)
                else:
                    raise ValueError(f"Unknown cmd {cmd}")
            except Exception as e:
                step_ok, ok, err = False, False, str(e)
            results.append({"i": i, "cmd": cmd, "arg": arg, "ok": step_ok, "error": err, "url": page.url})
            if not step_ok:
                break
        context.close(); browser.close()
    return ok, results

def load_cfg(repo_root: Path):
    path = repo_root / "pipeline.config.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8-sig"))
    return {}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", required=True, help="AkÄ±ÅŸ dosyasÄ± (.flow)")
    ap.add_argument("--out", required=True, help="JSON rapor yolu")
    ap.add_argument("--base-url", default=None)
    args = ap.parse_args()

    repo = Path(__file__).resolve().parents[1]
    cfg = load_cfg(repo)
    pwcfg = cfg.get("playwright", {})
    base_url = args.base_url or pwcfg.get("base_url", "http://127.0.0.1:8000")
    headless = pwcfg.get("headless", True)
    viewport = pwcfg.get("viewport", {"width": 1280, "height": 800})

    text = Path(args.steps).read_text(encoding="utf-8-sig")
    text = expand_env(text)
    steps = parse_steps(text)

    ok, results = run_flow(base_url, steps, headless=headless, viewport=viewport)
    out = Path(args.out); out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"ok": ok, "results": results}, ensure_ascii=False, indent=2), encoding="utf-8")

    print("[PW-FLOW] PASSED" if ok else "[PW-FLOW] FAILED")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()

