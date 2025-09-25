# REV: 1.1 | 2025-09-25 | Hash: a157f3d5 | Parça: 1/1
import argparse, json, os, sys
from glob import glob

try:
    from PIL import Image
except Exception as e:
    print(f"[LAYOUT] Pillow gerekli: {e}")
    sys.exit(2)

def latest_png(folder):
    files = sorted(glob(os.path.join(folder, "*.png")), key=os.path.getmtime)
    return files[-1] if files else None

def nmae_similarity(a_path, b_path):
    # 0 fark = 1.0 benzerlik; max fark ~1.0 => 0.0 benzerlik
    a = Image.open(a_path).convert("RGB")
    b = Image.open(b_path).convert("RGB")
    if a.size != b.size:
        b = b.resize(a.size)
    a_px = a.load(); b_px = b.load()
    w, h = a.size
    total = 0
    for y in range(h):
        for x in range(w):
            ar, ag, ab = a_px[x, y]
            br, bg, bb = b_px[x, y]
            total += abs(ar-br) + abs(ag-bg) + abs(ab-bb)
    max_total = (255*3) * w * h
    mae = total / max_total
    return max(0.0, 1.0 - mae)

def parse_improvements(path):
    if not os.path.exists(path): return {"all_done": False, "items": []}
    items = []
    all_done = True
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if s.startswith("[x]"):
                items.append({"text": s[3:].strip(), "done": True})
            elif s.startswith("[ ]"):
                items.append({"text": s[3:].strip(), "done": False})
                all_done = False
    return {"all_done": all_done, "items": items}

def read_playwright_status(report_json):
    if not report_json or not os.path.exists(report_json): return None
    try:
        with open(report_json, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("status")
    except Exception:
        return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True)
    ap.add_argument("--latest", required=True, help="folder of latest screenshots")
    ap.add_argument("--improve", required=True, help="improvements.txt")
    ap.add_argument("--report", required=True)
    ap.add_argument("--threshold", type=float, default=0.90)
    ap.add_argument("--playwright_json", default=None)
    args = ap.parse_args()

    os.makedirs(os.path.dirname(args.report), exist_ok=True)

    latest = latest_png(args.latest)
    if not latest:
        out = {"ok": False, "reason": "no_latest_screenshot"}
        print("[LAYOUT] No latest screenshot found.")
        with open(args.report, "w", encoding="utf-8") as f: json.dump(out, f, ensure_ascii=False, indent=2)
        return 1

    similarity = nmae_similarity(args.target, latest)
    screenshot_ok = (similarity >= args.threshold)

    imp = parse_improvements(args.improve)
    improvements_ok = imp["all_done"]

    tests_status = read_playwright_status(args.playwright_json)
    tests_ok = (tests_status == "passed") if tests_status is not None else True  # tests yoksa esnek davran

    ok = screenshot_ok and improvements_ok and tests_ok
    out = {
        "ok": ok,
        "similarity": round(similarity, 4),
        "threshold": args.threshold,
        "screenshot_ok": screenshot_ok,
        "improvements_ok": improvements_ok,
        "tests_ok": tests_ok,
        "latest_screenshot": os.path.relpath(latest),
        "target": os.path.relpath(args.target),
        "improvements_summary": imp
    }
    print(f"[LAYOUT] similarity={out['similarity']} ok={ok} "
          f"(shot>={args.threshold}={screenshot_ok}, improvements={improvements_ok}, tests={tests_ok})")
    with open(args.report, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
