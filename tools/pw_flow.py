# -*- coding: utf-8 -*-
import os, sys, json, time, re, pathlib, io, math, unicodedata, csv, datetime
from contextlib import contextmanager
from typing import List, Tuple, Dict, Any
from PIL import Image
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Error as PWError

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8010").rstrip("/")

try:
    import pytesseract
    _tcmd = os.environ.get("TESSERACT_CMD")
    if _tcmd and os.path.exists(_tcmd):
        pytesseract.pytesseract.tesseract_cmd = _tcmd
    else:
        if os.name == "nt":
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

def _parse_kv(s: str) -> Dict[str, str]:
    out = {}
    parts = s.strip().split()
    for part in parts:
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
    return out

def _nowstamp() -> str:
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")

def _norm_text(s: str) -> str:
    s = s.replace("İ", "i").replace("I", "ı")
    s = s.lower()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"[^a-z0-9ğüşöçı\-_/]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def _tokens(s: str) -> list:
    s = _norm_text(s)
    return [t for t in re.split(r"\s+", s) if len(t) >= 2]

def _ocr_text(img_path: str, lang: str = "tur+eng") -> str:
    if not pytesseract:
        return ""
    try:
        with Image.open(img_path) as im:
            return pytesseract.image_to_string(im, lang=lang) or ""
    except Exception:
        return ""

def _page_screenshot(page, out_path: str) -> str:
    path = _abs_path(out_path)
    page.screenshot(path=path, full_page=False)
    return path

def _visual_similarity_mse(baseline_path: str, live_path: str) -> float:
    try:
        with Image.open(baseline_path).convert("RGB") as b, Image.open(live_path).convert("RGB") as l:
            l = l.resize(b.size)
            bp = list(b.getdata()); lp = list(l.getdata())
            se = 0
            for (r1,g1,b1),(r2,g2,b2) in zip(bp, lp):
                dr, dg, db = r1-r2, g1-g2, b1-b2
                se += dr*dr + dg*dg + db*db
            mse = se / (len(bp)*3.0*255*255)
            return max(0.0, 1.0 - mse)
    except Exception:
        return 0.0

def _write_alert(key: str, ok: bool, recall: float, misses: list, paths: dict, alert_dir: str, reasons: list) -> str:
    adir = pathlib.Path(_abs_path(alert_dir)); adir.mkdir(parents=True, exist_ok=True)
    ts = _nowstamp()
    md_path = adir / f"{key}-{ts}.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"# AUTOVALIDATE: {key}\n\n")
        f.write(f"- Zaman: {ts}\n- Sonuç: {'OK' if ok else 'FAIL'}\n- Recall: {recall:.3f}\n")
        if reasons: f.write(f"- Neden(ler): {', '.join(reasons)}\n")
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

from contextlib import contextmanager
@contextmanager
def browser_ctx(headless: bool):
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=headless)
        context = browser.new_context()
        page = context.new_page()
        page.set_default_timeout(30_000)
        try:
            yield page, context, browser
        finally:
            try: context.close()
            except Exception: pass
            try: browser.close()
            except Exception: pass

def run_flow(steps: list, headless: bool=False):
    results = []; ok_all = True
    with browser_ctx(headless=headless) as (page, _ctx, _br):
        for i, raw in enumerate(steps, start=1):
            cmd, arg = _parse_line(raw)
            if cmd == "COMMENT": continue
            step_ok, err = True, None
            # defaults for AUTOVALIDATE enrichment
            recall=1.0; sim=1.0; ok_words=True; ok_vis=True; ok_selects=True; missing=[]
            try:
                if cmd == "GOTO":
                    page.goto(_resolve_url(arg.strip()), wait_until="domcontentloaded")
                elif cmd == "WAIT":
                    a = arg.strip(); aU = a.upper()
                    if aU.startswith("SELECTOR "):
                        sel = a[len("SELECTOR "):].strip()
                        page.wait_for_selector(sel, state="visible")
                    elif aU.startswith("URL CONTAINS "):
                        needle = a[len("URL CONTAINS "):].strip()
                        deadline = time.time() + 30
                        while time.time() < deadline:
                            if needle in page.url: break
                            time.sleep(0.1)
                        else:
                            raise PWTimeout(f'URL does not contain "{needle}"')
                    else:
                        raise PWError(f"Unsupported WAIT arg: {arg}")
                elif cmd == "FILL":
                    sp = arg.split(None, 1)
                    if len(sp) < 2: raise PWError("FILL requires 'selector text'")
                    sel, txt = sp[0], sp[1]; page.fill(sel, txt)
                elif cmd == "CLICK":
                    page.click(arg.strip())
                elif cmd == "SCREENSHOT":
                    page.screenshot(path=_abs_path(arg.strip()), full_page=False)
                elif cmd == "SELECT":
                    m = re.match(r"(\S+)\s+(.+)$", arg.strip())
                    if not m: raise PWError("SELECT needs: <selector> key=value")
                    sel, rest = m.group(1), m.group(2); kv = _parse_kv(rest)
                    if   "label" in kv: page.select_option(sel, label=kv["label"])
                    elif "value" in kv: page.select_option(sel, value=kv["value"])
                    elif "index" in kv: page.select_option(sel, index=int(kv["index"]))
                    else: raise PWError("SELECT requires one of label=, value=, index=")
                elif cmd == "EXPECTTEXT":
                    m = re.match(r"(\S+)\s+(equals|contains)\s+(.+)$", arg.strip(), re.I)
                    if not m: raise PWError("EXPECTTEXT: '<selector> equals|contains <text>'")
                    sel, mode, text = m.group(1), m.group(2).lower(), m.group(3)
                    got = page.inner_text(sel).strip()
                    if mode == "equals":
                        if _norm_text(got) != _norm_text(text): raise AssertionError(f"EXPECTTEXT equals fail: got='{got}' want='{text}'")
                    else:
                        if _norm_text(text) not in _norm_text(got): raise AssertionError(f"EXPECTTEXT contains fail: got='{got}' want contains '{text}'")
                elif cmd == "EXPECTVALUE":
                    m = re.match(r"(\S+)\s+(.+)$", arg.strip())
                    if not m: raise PWError("EXPECTVALUE: '<selector> <value>'")
                    sel, want = m.group(1), m.group(2)
                    val = page.eval_on_selector(sel, "el => el.value")
                    if _norm_text(str(val)) != _norm_text(str(want)): raise AssertionError(f"EXPECTVALUE fail: got='{val}' want='{want}'")
                elif cmd == "AUTOVALIDATE":
                    kv = _parse_kv(arg)
                    key = kv.get("key", "page")
                    baseline = _abs_path(kv["baseline"]) if "baseline" in kv else None
                    words_recall = float(kv.get("words_recall", "0.9"))
                    live_source = kv.get("live_source", "dom+ocr").lower()
                    check_selects = kv.get("check_selects", "yes").lower() == "yes"
                    vis_thresh = float(kv.get("vis_thresh", "0.9"))
                    alert_on = kv.get("alert", "on").lower() == "on"
                    alert_dir = kv.get("alert_dir", "_otokodlama/alerts")

                    reasons = []
                    # run+log even if exceptions happen
                    try:
                        baseline_text = ""
                        if baseline and os.path.exists(baseline):
                            baseline_text = _ocr_text(baseline) if pytesseract else ""
                        live_texts = []
                        if live_source in ("dom","dom+ocr"):
                            try: live_texts.append( (page.locator("body").inner_text()) )
                            except Exception: pass

                        live_shot = f"_otokodlama/alerts/{key}-live-{_nowstamp()}.png"
                        live_shot_abs = _page_screenshot(page, live_shot)

                        if live_source in ("ocr","dom+ocr") and pytesseract:
                            live_texts.append(_ocr_text(live_shot_abs))

                        base_tokens = set(_tokens(baseline_text))
                        live_tokens = set(_tokens(" ".join(live_texts)))
                        inter = base_tokens & live_tokens if base_tokens else set()
                        recall = (len(inter) / max(1, len(base_tokens))) if base_tokens else 1.0
                        ok_words = (recall >= words_recall)
                        missing = sorted(list(base_tokens - live_tokens))

                        ok_vis = True; sim = 1.0
                        if baseline and os.path.exists(baseline):
                            sim = _visual_similarity_mse(baseline, live_shot_abs)
                            if sim < vis_thresh:
                                ok_vis = False; reasons.append(f"visual<{vis_thresh:.2f} ({sim:.3f})")

                        ok_selects = True
                        if check_selects:
                            try:
                                info = page.eval_on_selector_all("select",
                                    """els => els.map(e => ({
                                        id:e.id, name:e.name, disabled:e.disabled,
                                        options:[...e.options].map(o => ({value:o.value, label:o.label, disabled:o.disabled, selected:o.selected}))
                                    }))""")
                                tried = 0
                                for s in info:
                                    if s.get("disabled"): continue
                                    opts = [o for o in s.get("options", []) if not o.get("disabled")]
                                    if len(opts)>=1:
                                        sel = f"select#{s['id']}" if s.get("id") else f"select[name='{s.get('name','')}']"
                                        page.select_option(sel, value=opts[0]["value"])
                                        tried += 1; break
                            except Exception:
                                ok_selects = False; reasons.append("selects-fail")

                        if not ok_words: reasons.append(f"words_recall<{words_recall:.2f} ({recall:.3f})")
                        ok = ok_words and ok_vis and ok_selects
                        if alert_on and (not ok):
                            _write_alert(key, ok, recall, missing, {"baseline": baseline or "(yok)", "live_screenshot": live_shot_abs}, alert_dir, reasons)
                        if not ok:
                            raise AssertionError("AUTOVALIDATE FAIL: " + ", ".join(reasons))
                    except Exception as e:
                        # always log a fail with whatever we have
                        try:
                            live_shot = f"_otokodlama/alerts/{key}-live-{_nowstamp()}.png"
                            live_shot_abs = _page_screenshot(page, live_shot)
                        except Exception:
                            live_shot_abs = "(no-shot)"
                        _write_alert(key, False, float(recall), missing, {"baseline": baseline or "(yok)", "live_screenshot": live_shot_abs}, alert_dir, reasons + [f"exception:{e}"])
                        raise

                else:
                    raise PWError(f"Unknown cmd: {cmd}")
            except (PWTimeout, PWError, AssertionError) as e:
                step_ok, err = False, f"{e.__class__.__name__}: {str(e)}"
                ok_all = False

            rec = {"i": i, "cmd": cmd, "arg": arg, "ok": step_ok, "error": err,
                   "url": page.url if page else "about:blank"}
            if cmd == "AUTOVALIDATE":
                rec.update({
                    "recall": float(recall), "visual_sim": float(sim),
                    "ok_words": bool(ok_words), "ok_visual": bool(ok_vis),
                    "ok_selects": bool(ok_selects), "missing_count": len(missing)
                })
            results.append(rec)
            if not step_ok: break
    return ok_all, results

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--headful", action="store_true")
    args = ap.parse_args()
    with open(args.steps, "r", encoding="utf-8-sig") as f:
        text = f.read()
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

