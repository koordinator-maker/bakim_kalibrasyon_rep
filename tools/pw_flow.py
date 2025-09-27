# -*- coding: utf-8 -*-
import os, sys, json, time, pathlib, re
from contextlib import contextmanager
from typing import List, Tuple, Dict, Any
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

def _read_words(words_path: str) -> List[str]:
    if not words_path: return []
    p = pathlib.Path(words_path)
    if not p.exists(): return []
    out = []
    for line in p.read_text(encoding="utf-8").splitlines():
        t = line.strip()
        if not t or t.startswith("#"): continue
        out.append(t)
    return out

def _normalize_text(t: str) -> str:
    # Basit normalize: whitespace sadeleştir, UTF-8 koru, casefold ile küçük-büyük hassasiyeti azalt
    return " ".join(t.split()).casefold()

def _page_dom_text(page) -> str:
    try:
        return page.evaluate("document.body ? (document.body.innerText || '') : ''")
    except Exception:
        return ""

def _screenshot_and_ocr(page, shot_path: str, ocr_lang: str) -> str:
    # Ekran görüntüsü al ve OCR metni döndür (pytesseract yüklü değilse boş)
    from PIL import Image
    page.screenshot(path=_abs_path(shot_path), full_page=False)
    try:
        import pytesseract
    except Exception:
        return ""
    try:
        img = Image.open(_abs_path(shot_path))
        txt = pytesseract.image_to_string(img, lang=ocr_lang or "tur+eng")
        return txt or ""
    except Exception:
        return ""

def _image_similarity(path_a: str, path_b: str) -> float:
    # Basit piksel benzerliği (1.0 = aynı). Baseline yoksa -1 döndür.
    pa = pathlib.Path(path_a); pb = pathlib.Path(path_b)
    if not pa.exists() or not pb.exists(): return -1.0
    from PIL import Image, ImageChops
    a = Image.open(str(pa)).convert("RGB")
    b = Image.open(str(pb)).convert("RGB")
    if a.size != b.size:
        b = b.resize(a.size)
    diff = ImageChops.difference(a, b)
    bbox = diff.getbbox()
    if not bbox:
        return 1.0
    # normalize fark: diff piksel intensitesinin ortalaması ~ basit skor
    # (Hafif/kolay yöntem; SSIM yok, ek bağımlılık istemedik)
    import numpy as np
    arr = np.array(diff, dtype="float32") / 255.0
    mean_diff = float(arr.mean())  # 0..1
    sim = max(0.0, 1.0 - mean_diff)
    return sim

def _kv_args(arg: str) -> Dict[str, str]:
    kv = {}
    for part in re.split(r"\s+", arg.strip()):
        if "=" in part:
            k,v = part.split("=",1)
            kv[k.strip().lower()] = v.strip()
    return kv

def run_autovalidate(page, arg: str) -> Dict[str, Any]:
    """
    AUTOVALIDATE key=admin_home [words=ops/expect/admin_home.words.txt] [baseline=targets/reference/admin_home.png]
                  [vis_thresh=0.90] [words_mode=or|dom_only|ocr_only] [require=all|min_hit=...] [check_selects=yes|no]
                  [ocr_lang=tur+eng] [shot=_otokodlama/out/auto/admin_home.png]
    """
    p = _kv_args(arg)
    key = p.get("key", "page")
    # words dosyası resolve
    words = p.get("words") or f"ops/expect/{key}.words.txt"
    if not pathlib.Path(words).exists():
        alt = "ops/expect/common.words.txt"
        words = alt if pathlib.Path(alt).exists() else ""
    expected = _read_words(words)

    baseline = p.get("baseline") or f"targets/reference/{key}.png"
    vis_thresh = float(p.get("vis_thresh", "0.90"))
    words_mode = p.get("words_mode", "or").lower()         # or | dom_only | ocr_only
    require = p.get("require", "all").lower()              # all | any
    min_hit = int(p.get("min_hit", "0"))
    check_selects = p.get("check_selects","yes").lower() in ("yes","1","true","on")
    ocr_lang = p.get("ocr_lang","tur+eng")
    shot = p.get("shot") or f"_otokodlama/out/auto/{key}.png"

    # 1) DOM metni
    dom_text = _page_dom_text(page)
    dom_norm = _normalize_text(dom_text)

    # 2) OCR (aynı anda ekran görüntüsü üretir)
    ocr_text = _screenshot_and_ocr(page, shot, ocr_lang)
    ocr_norm = _normalize_text(ocr_text)

    def _match_words(source_norm: str, words: List[str]) -> Dict[str, Any]:
        hits = []
        misses = []
        for w in words:
            wn = _normalize_text(w)
            if wn and wn in source_norm:
                hits.append(w)
            else:
                misses.append(w)
        return {"hits": hits, "misses": misses}

    word_report = {"expected": expected, "mode": words_mode, "require": require, "min_hit": min_hit}
    dom_rep = _match_words(dom_norm, expected) if expected else {"hits": [], "misses": []}
    ocr_rep = _match_words(ocr_norm, expected) if expected else {"hits": [], "misses": []}

    # Sözleşme: varsayılan 'or' => kelime DOM **veya** OCR içinde geçiyorsa hit sayılır.
    combined_hits = set(dom_rep["hits"]) | set(ocr_rep["hits"])
    if words_mode == "dom_only":
        combined_hits = set(dom_rep["hits"])
    elif words_mode == "ocr_only":
        combined_hits = set(ocr_rep["hits"])
    combined_misses = [w for w in expected if w not in combined_hits]

    # Kabul kriteri
    ok_words = True
    if expected:
        if require == "all":
            ok_words = (len(combined_misses) == 0)
        else:
            need = min_hit if min_hit > 0 else 1
            ok_words = (len(combined_hits) >= need)

    # 3) Select (pulldown) denemeleri
    selects_info = []
    selects_ok = True
    if check_selects:
        try:
            sels = page.query_selector_all("select")
            for s in sels:
                try:
                    if not s.is_visible(): 
                        selects_info.append({"selector":"select", "visible": False, "changed": None, "error": None})
                        continue
                except Exception:
                    selects_info.append({"selector":"select", "visible": False, "changed": None, "error": "visibility_err"})
                    continue
                try:
                    cur = s.input_value()
                except Exception:
                    cur = ""
                opts = s.query_selector_all("option")
                vals = []
                for o in opts:
                    try:
                        if not o.is_disabled():
                            v = o.get_attribute("value") or ""
                            vals.append(v)
                    except Exception:
                        pass
                changed = False
                err = None
                target = None
                for v in vals:
                    if v and v != cur:
                        target = v
                        try:
                            s.select_option(value=v)
                            newv = s.input_value()
                            changed = (newv == v)
                        except Exception as e:
                            err = str(e)
                        break
                selects_info.append({"selector":"select", "visible": True, "current": cur, "target": target, "changed": changed, "error": err})
                if changed is False and err:
                    selects_ok = False
        except Exception as e:
            selects_ok = False
            selects_info.append({"selector":"*", "error": f"select_scan_failed: {e}"})

    # 4) Görsel benzerlik (baseline varsa)
    vis_sim = _image_similarity(_abs_path(shot), _abs_path(baseline))
    vis_ok = True
    if vis_sim >= 0:
        vis_ok = (vis_sim >= vis_thresh)

    detail = {
        "key": key,
        "words_file": words,
        "baseline": baseline,
        "screenshot": shot,
        "dom": {"len": len(dom_text)},
        "ocr": {"len": len(ocr_text), "lang": ocr_lang},
        "words": {
            "expected_count": len(expected),
            "hits": sorted(list(combined_hits)),
            "misses": combined_misses,
            "ok": ok_words,
            "mode": words_mode,
            "require": require,
            "min_hit": min_hit,
        },
        "selects": {"ok": selects_ok, "items": selects_info},
        "visual": {"ok": vis_ok, "similarity": vis_sim, "threshold": vis_thresh},
    }
    # Genel karar: sözler (varsa) OK VE selectler OK VE (baseline varsa) görsel OK
    ok = ok_words and selects_ok and vis_ok

    # Ayrıntı raporunu da kaydet
    out_detail = pathlib.Path(f"_otokodlama/out/autovalidate_{key}.json")
    out_detail.parent.mkdir(parents=True, exist_ok=True)
    out_detail.write_text(json.dumps(detail, ensure_ascii=False, indent=2), encoding="utf-8")

    return {"ok": ok, "detail_path": str(out_detail), **detail}

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
                elif cmd == "SELECT":
                    parts = arg.split()
                    if not parts:
                        raise PWError("SELECT requires arguments")
                    sel = parts[0]
                    kv = {}
                    for p in parts[1:]:
                        if "=" in p:
                            k, v = p.split("=", 1)
                            kv[k.strip().lower()] = v.strip()
                    if not kv:
                        raise PWError("SELECT needs value=... or label=... or index=...")
                    opt = {}
                    if "value" in kv: opt["value"] = kv["value"]
                    if "label" in kv: opt["label"] = kv["label"]
                    if "index" in kv: opt["index"] = int(kv["index"])
                    page.select_option(sel, opt)
                elif cmd == "EXPECTTEXT":
                    parts = arg.split(None, 2)
                    if len(parts) < 3:
                        raise PWError("EXPECTTEXT <selector> <equals|contains> <text>")
                    sel, mode, text = parts[0], parts[1].lower(), parts[2]
                    actual = page.inner_text(sel).strip()
                    if mode in ("equals", "=="):
                        if actual != text:
                            raise AssertionError(f'EXPECTTEXT equals failed: "{actual}" != "{text}"')
                    elif mode in ("contains", "~="):
                        if text not in actual:
                            raise AssertionError(f'EXPECTTEXT contains failed: "{text}" not in "{actual}"')
                    else:
                        raise PWError(f"Unsupported EXPECTTEXT mode: {mode}")
                elif cmd == "EXPECTVALUE":
                    parts = arg.split(None, 1)
                    if len(parts) < 2:
                        raise PWError("EXPECTVALUE <selector> <expected>")
                    sel, expected = parts[0], parts[1]
                    val = page.locator(sel).input_value()
                    if val != expected:
                        raise AssertionError(f'EXPECTVALUE failed: "{val}" != "{expected}"')
                elif cmd == "AUTOVALIDATE":
                    rep = run_autovalidate(page, arg)
                    step_ok = rep.get("ok", False)
                    results.append({
                        "i": i, "cmd": cmd, "arg": arg, "ok": step_ok, "error": None if step_ok else "AUTOVALIDATE failed",
                        "url": page.url, "report": rep
                    })
                    if not step_ok:
                        ok_all = False
                        break
                    continue
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