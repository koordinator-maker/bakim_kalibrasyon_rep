# REV: 1.0 | 2025-09-25 | Hash: bfa8286c | ParÃ§a: 1/1
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# REV: 1.1 | tools/playwright_tests.py (BOM-safe)

import sys, json, argparse
from pathlib import Path

def load_config(repo_root: Path):
    cfg_path = repo_root / "pipeline.config.json"
    cfg = json.loads(cfg_path.read_text(encoding="utf-8-sig"))
    return cfg

def normalize_urls(lines, base_url: str):
    out = []
    for raw in lines:
        u = raw.strip().lstrip("\ufeff")  # satÄ±r baÅŸÄ±ndaki BOM'u sÃ¼pÃ¼r
        if not u or u.startswith("#"):
            continue
        if u.startswith("/"):
            u = base_url.rstrip("/") + u
        out.append(u)
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--urls", required=True, help="URL listesi dosyasÄ±")
    ap.add_argument("--out", required=True, help="JSON rapor ('.json' ile biter)")
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    cfg = load_config(repo_root)
    pwcfg = cfg.get("playwright", {})
    base_url = pwcfg.get("base_url", "http://127.0.0.1:8000")
    headless = pwcfg.get("headless", True)
    viewport = pwcfg.get("viewport", {"width": 1280, "height": 800})
    timeout_ms = 15000  # 15s

    # KRÄ°TÄ°K: URL dosyasÄ±nda gizli BOM olursa otomatik temizle
    lines = Path(args.urls).read_text(encoding="utf-8-sig").splitlines()
    urls = normalize_urls(lines, base_url)

    from playwright.sync_api import sync_playwright

    results = []
    fail = 0
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=headless)
        context = browser.new_context(viewport=viewport)
        for url in urls:
            page = context.new_page()
            console_errors = []
            page.on("console", lambda m: console_errors.append(m.text) if m.type == "error" else None)
            status = None; ok = False; err = None; title = None
            try:
                resp = page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)
                status = resp.status if resp else None
                title = page.title()
                ok = (status is not None and status < 400)
            except Exception as e:
                err = str(e)
                ok = False
            results.append({
                "url": url,
                "status": status,
                "title": title,
                "console_errors": console_errors[:10],
                "ok": bool(ok),
                "error": err
            })
            if not ok:
                fail += 1
            page.close()
        context.close()
        browser.close()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.suffix.lower() != ".json":
        out_path = out_path.with_suffix(".json")
    report = {"total": len(urls), "fail": fail, "results": results}
    out_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if fail == 0:
        print(f"[PLAYWRIGHT] PASSED - total={len(urls)} fail=0")
        sys.exit(0)
    else:
        print(f"[PLAYWRIGHT] FAILED - total={len(urls)} fail={fail}")
        for r in results:
            if not r["ok"]:
                print(f"  FAIL {r['url']} status={r['status']} error={r['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()





