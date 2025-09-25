# REV: 1.1 | 2025-09-25 | Hash: 9e21d893 | Parça: 1/1
import argparse, json, os, sys, time

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--urls", required=True, help="URLs file (one per line)")
    ap.add_argument("--out", required=True, help="Output folder")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    report_json = os.path.join(args.out, "report.json")
    report_txt  = os.path.join(args.out, "report.txt")

    try:
        from playwright.sync_api import sync_playwright
    except Exception as e:
        msg = f"[PLAYWRIGHT] import failed: {e}\nInstall: pip install playwright && playwright install chromium"
        print(msg)
        with open(report_txt, "w", encoding="utf-8") as f: f.write(msg + "\n")
        with open(report_json, "w", encoding="utf-8") as f: json.dump({"status":"error","error":str(e)}, f, ensure_ascii=False, indent=2)
        return 2

    urls = []
    with open(args.urls, "r", encoding="utf-8") as f:
        for line in f:
            u = line.strip()
            if u and not u.startswith("#"):
                urls.append(u)

    results = []
    failures = 0
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()
        for u in urls:
            rec = {"url": u, "ok": False, "load_ms": None, "error": None}
            t0 = time.time()
            try:
                page.goto(u, timeout=30000, wait_until="domcontentloaded")
                page.wait_for_load_state("networkidle", timeout=15000)
                rec["ok"] = True
            except Exception as e:
                rec["error"] = str(e)
                failures += 1
            finally:
                rec["load_ms"] = int((time.time() - t0) * 1000)
                # her URL için küçük bir ekran görüntüsü
                shot_path = os.path.join(args.out, f"pw_{int(time.time()*1000)}.png")
                try:
                    page.screenshot(path=shot_path, full_page=True)
                    rec["screenshot"] = os.path.basename(shot_path)
                except Exception as _:
                    rec["screenshot"] = None
                results.append(rec)
        context.close(); browser.close()

    status = "passed" if failures == 0 else "failed"
    summary = f"[PLAYWRIGHT] {status.upper()} - total={len(results)} fail={failures}"
    print(summary)

    with open(report_txt, "w", encoding="utf-8") as f:
        f.write(summary + "\n")
        for r in results:
            f.write(f"- {r['url']} | ok={r['ok']} | {r['load_ms']}ms | err={r['error']}\n")

    with open(report_json, "w", encoding="utf-8") as f:
        json.dump({"status": status, "failures": failures, "results": results}, f, ensure_ascii=False, indent=2)

    return 0 if failures == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
