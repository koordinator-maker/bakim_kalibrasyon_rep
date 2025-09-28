# -*- coding: utf-8 -*-
import os, sys, json, time, re, pathlib, io, math, unicodedata, csv, datetime, hashlib
from typing import Tuple, Dict
from contextlib import contextmanager

from PIL import Image
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Error as PWError

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8010").rstrip("/")

# --- OCR (opsiyonel) ---
try:
    import pytesseract
    _tcmd = os.environ.get("TESSERACT_CMD")
    if _tcmd and os.path.exists(_tcmd):
        pytesseract.pytesseract.tesseract_cmd = _tcmd
    elif os.name == "nt":
        _cand = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
        if os.path.exists(_cand):
            pytesseract.pytesseract.tesseract_cmd = _cand
except Exception:
    pytesseract = None

def _abs_path(p: str) -> str:
    p = p.replace("\\", "/")
    full = (pathlib.Path.cwd() / p).resolve()
    full.parent.mkdir(parents=True, exist_ok=True)
    return str(full)

def _resolve_url(arg: str) -> str:
    if arg.startswith(("http://","https://")): return arg
    if not arg.startswith("/"): arg = "/" + arg
    return BASE_URL + arg

def _parse_line(line: str):
    line = line.strip()
    if not line or line.startswith("#"): return ("COMMENT", line)
    sp = line.split(None, 1)
    return (sp[0].upper(), sp[1] if len(sp)>1 else "")

def _parse_kv(s: str) -> Dict[str,str]:
    out = {}
    for part in s.strip().split():
        if "=" in part:
            k,v = part.split("=",1); out[k.strip()] = v.strip()
    return out

def _nowstamp(): return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")

def _norm_text(s: str) -> str:
    s = s.replace("İ","i").replace("I","ı").lower()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"[^a-z0-9ğüşöçı\-\_/]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def _tokenize_for_compare(text: str, min_len=3, ignore_numbers=True, ignore_patterns=None):
    txt = _norm_text(text)
    toks = [t for t in re.split(r"\s+", txt) if t]
    out = []
    regs = []
    if ignore_patterns:
        for pat in ignore_patterns:
            try: regs.append(re.compile(pat, re.I))
            except Exception: pass
    for t in toks:
        if len(t) < min_len: continue
        if ignore_numbers and t.isdigit(): continue
        if any(r.search(t) for r in regs): continue
        out.append(t)
    return out

def _ocr_text(img_path: str, lang="tur+eng") -> str:
    if not pytesseract: return ""
    try:
        with Image.open(img_path) as im:
            return pytesseract.image_to_string(im, lang=lang) or ""
    except Exception:
        return ""

def _page_screenshot(page, out_path: str) -> str:
    path = _abs_path(out_path)
    page.screenshot(path=path, full_page=False)
    return path

def _write_alert(key: str, ok: bool, recall: float, misses: list, paths: dict, alert_dir: str, reasons: list) -> str:
    adir = pathlib.Path(_abs_path(alert_dir)); adir.mkdir(parents=True, exist_ok=True)
    ts = _nowstamp()
    md_path = adir / f"{key}-{ts}.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"# AUTOVALIDATE: {key}\n\n- Zaman: {ts}\n- Sonuç: {'OK' if ok else 'FAIL'}\n- Recall: {recall:.3f}\n")
        if reasons: f.write(f"- Neden: {', '.join(reasons)}\n")
        f.write("\n## Eksik Kelimeler\n")
        if misses:
            for w in sorted(misses)[:200]: f.write(f"- {w}\n")
        else:
            f.write("- (yok)\n")
        f.write("\n## Dosyalar\n")
        for k,v in paths.items(): f.write(f"- **{k}**: `{v}`\n")
    csv_path = adir / "alerts_log.csv"
    header = ["ts","key","ok","recall","misses","alert_md"]
    row = [ts, key, str(ok), f"{recall:.4f}", str(len(misses)), str(md_path)]
    write_header = not csv_path.exists()
    with open(csv_path, "a", encoding="utf-8", newline="") as cf:
        w = csv.writer(cf, delimiter=";")
        if write_header: w.writerow(header)
        w.writerow(row)
    return str(md_path)

@contextmanager
def browser_ctx(headless=True, har_path=None):
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=headless)
        if har_path:
            context = browser.new_context(record_har_path=_abs_path(har_path), record_har_content="embed")
        else:
            context = browser.new_context()
        page = context.new_page()
        page.set_default_timeout(30_000)
        page.on('popup', lambda p: (p.close() if not p.is_closed() else None))
        try:
            yield page, context, browser
        finally:
            try: context.close()
            except: pass
            try: browser.close()
            except: pass

def run_flow(steps: list, headless=True, har_path=None):
    results=[]; ok_all=True
    with browser_ctx(headless=headless, har_path=har_path) as (page, _ctx, _br):
        for i, raw in enumerate(steps, start=1):
            cmd, arg = _parse_line(raw)
            if cmd == "COMMENT": 
                results.append({"i": i, "cmd": cmd, "arg": arg, "ok": True, "error": "", "url": page.url if page else ""})
                continue
            step_ok=True; err=None
            # AUTOVAL outputs
            recall=1.0; ok_words=True; missing=[]; reasons=[]

            try:
                if cmd == "GOTO":
                    page.goto(_resolve_url(arg.strip()), wait_until="domcontentloaded")

                elif cmd == "WAIT":
                    a = arg.strip(); aU=a.upper()
                    if aU.startswith("SELECTOR "):
                        sel = a[len("SELECTOR "):].strip()
                        page.wait_for_selector(sel, state="visible")
                    elif aU.startswith("URL CONTAINS "):
                        needle = a[len("URL CONTAINS "):].strip()
                        deadline = time.time()+30
                        while time.time() < deadline:
                            if needle in page.url: break
                            time.sleep(0.1)
                        else: raise PWTimeout(f'URL does not contain "{needle}"')
                    else:
                        raise PWError(f"Unsupported WAIT arg: {arg}")

                elif cmd == "FILL":
                    sp = arg.split(None, 1)
                    if len(sp) < 2: raise PWError("FILL requires 'selector text'")
                    sel, txt = sp[0], sp[1]
                    page.fill(sel, txt)

                elif cmd == "CLICK":
                    page.click(arg.strip())
                    try: page.wait_for_load_state("domcontentloaded", timeout=10000)
                    except: pass
                    if page.url.startswith("chrome-error://"):
                        raise PWError("navigation-error")

                elif cmd == "SCREENSHOT":
                    page.screenshot(path=_abs_path(arg.strip()), full_page=False)

                elif cmd == "DUMPDOM":
                    path = _abs_path(arg.strip())
                    html = page.content()
                    pathlib.Path(path).write_text(html, encoding="utf-8")

                elif cmd == "AUTOVALIDATE":
                    kv = _parse_kv(arg)
                    key = kv.get("key","page")
                    baseline = _abs_path(kv["baseline"]) if "baseline" in kv else None
                    words_recall = float(kv.get("words_recall","0.90"))
                    live_source = kv.get("live_source","dom").lower()  # dom | ocr | dom+ocr
                    alert_dir = kv.get("alert_dir","_otokodlama/alerts")
                    min_token_len = int(kv.get("min_token_len","3"))
                    ignore_numbers = kv.get("ignore_numbers","yes").lower() == "yes"
                    ignore_patterns = [p for p in (x.strip() for x in kv.get("ignore_patterns","").split(",")) if p]

                    # 1) baseline OCR (opsiyonel)
                    baseline_text = ""
                    if baseline and os.path.exists(baseline) and "ocr" in live_source:
                        baseline_text = _ocr_text(baseline)
                    elif baseline and os.path.exists(baseline):
                        # baseline varsa ama OCR yoksa, baseline metni boş kalsın; sadece görsel referans gibi davranırız
                        baseline_text = ""

                    # 2) canlı DOM ve/veya OCR
                    live_texts=[]
                    if "dom" in live_source:
                        try: live_texts.append(page.locator("body").inner_text())
                        except: pass

                    live_shot = f"_otokodlama/alerts/{key}-live-{_nowstamp()}.png"
                    live_shot_abs = _page_screenshot(page, live_shot)

                    if "ocr" in live_source and pytesseract:
                        live_texts.append(_ocr_text(live_shot_abs))

                    # 3) kelime recall (baseline→live)
                    base_tokens = set(_tokenize_for_compare(
                        baseline_text, min_len=min_token_len, ignore_numbers=ignore_numbers, ignore_patterns=ignore_patterns
                    ))
                    live_tokens = set(_tokenize_for_compare(
                        " ".join(live_texts), min_len=min_token_len, ignore_numbers=ignore_numbers, ignore_patterns=ignore_patterns
                    ))
                    inter = base_tokens & live_tokens if base_tokens else set()
                    recall = (len(inter) / max(1, len(base_tokens))) if base_tokens else 1.0
                    ok_words = (recall >= words_recall)
                    missing = sorted(list(base_tokens - live_tokens))

                    if not ok_words:
                        reasons.append(f"words_recall<{words_recall:.2f} ({recall:.3f})")

                    ok = ok_words
                    if not ok:
                        _write_alert(key, ok, recall, missing, {"baseline": baseline or "(yok)", "live_screenshot": live_shot_abs}, alert_dir, reasons)
                        raise AssertionError("AUTOVALIDATE FAIL: " + ", ".join(reasons))

                else:
                    raise PWError(f"Unknown cmd: {cmd}")

            except (PWTimeout, PWError, AssertionError) as e:
                step_ok=False; err=f"{e.__class__.__name__}: {str(e)}"
                ok_all=False

            rec = {"i": i, "cmd": cmd, "arg": arg, "ok": step_ok, "error": err, "url": page.url if page else "about:blank"}
            if cmd == "AUTOVALIDATE":
                rec.update({"recall": float(recall), "ok_words": bool(ok_words), "missing_count": len(missing)})
            results.append(rec)
            if not step_ok: break
    return ok_all, results

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--headful", action="store_true")
    ap.add_argument("--har", default=None)
    args = ap.parse_args()

    with open(args.steps, "r", encoding="utf-8-sig") as f:
        text = f.read()
    steps = text.splitlines()
    ok, res = run_flow(steps, headless=(not args.headful), har_path=args.har)
    out = {"ok": ok, "results": res}
    pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("[PW-FLOW] " + ("PASSED" if ok else "FAILED"))
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()