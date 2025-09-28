import os, re, json, time, pathlib, contextlib
from typing import Tuple, List, Optional
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Error as PWError

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8010").rstrip("/")

def _resolve_url(arg: str) -> str:
    arg = arg.strip()
    if arg.startswith("http://") or arg.startswith("https://"):
        return arg
    if not arg.startswith("/"):
        arg = "/" + arg
    return BASE_URL + arg

def _parse_line(line: str) -> Tuple[str, str]:
    raw = line
    line = (line or "").rstrip("\r\n")
    stripped = line.strip()
    if not stripped:
        return "COMMENT", ""
    # tam satır yorumları: #, //, ;
    if stripped.startswith("#") or stripped.startswith("//") or stripped.startswith(";"):
        return "COMMENT", raw
    sp = stripped.split(None, 1)
    if len(sp) == 1:
        return sp[0].upper(), ""
    return sp[0].upper(), sp[1]

def _norm_text(s: str) -> str:
    return re.sub(r"\s+", " ", s or "").strip()

def _parse_kv(s: str):
    kv = {}
    for m in re.finditer(r'(\w+)\s*=\s*"([^"]*)"|(\w+)\s*=\s*\'([^\']*)\'|(\w+)\s*=\s*([^\s]+)', s or ""):
        key = m.group(1) or m.group(3) or m.group(5)
        val = m.group(2) or m.group(4) or m.group(6)
        kv[key] = val
    return kv

def _ensure_parent(path_str: str):
    if not path_str:
        return
    p = pathlib.Path(path_str)
    if p.parent:
        p.parent.mkdir(parents=True, exist_ok=True)

def _apply_timeouts(page, t: Optional[int]):
    if t and t > 0:
        try:
            page.set_default_timeout(t)
            page.set_default_navigation_timeout(t)
        except Exception:
            pass

@contextlib.contextmanager
def browser_ctx(headless: bool=False, har_path: Optional[str]=None, timeout_ms: Optional[int]=None):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=headless)
        if har_path:
            context = browser.new_context(record_har_path=har_path)
        else:
            context = browser.new_context()
        page = context.new_page()
        _apply_timeouts(page, timeout_ms)
        try:
            yield page, context, browser
        finally:
            with contextlib.suppress(Exception):
                context.close()
            with contextlib.suppress(Exception):
                browser.close()

def run_flow(steps: List[str], headless: bool=False, har_path: Optional[str]=None, timeout_ms: Optional[int]=None):
    results = []
    ok_all  = True
    with browser_ctx(headless=headless, har_path=har_path, timeout_ms=timeout_ms) as (page, _ctx, _br):
        for i, raw in enumerate(steps, start=1):
            cmd, arg = _parse_line(raw)
            if cmd == "COMMENT" or not cmd:
                continue
            step_ok, err = True, ""
            try:
                if cmd == "GOTO":
                    page.goto(_resolve_url(arg), wait_until="domcontentloaded")

                elif cmd == "WAIT":
                    a = (arg or "").strip()
                    aU = a.upper()
                    if aU.startswith("SELECTOR "):
                        sel = a[len("SELECTOR "):].strip()
                        page.wait_for_selector(sel, state="visible")
                    elif aU.startswith("SELECTOR-OR "):
                        rest = a[len("SELECTOR-OR "):]
                        candidates = [s.strip() for s in re.split(r"\|\|", rest) if s.strip()]
                        last_err = None
                        for sel in candidates:
                            try:
                                page.wait_for_selector(sel, state="visible")
                                last_err = None
                                break
                            except Exception as e:
                                last_err = e
                        if last_err:
                            raise last_err
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
                    sp = re.split(r"\s+", arg or "", maxsplit=1)
                    if len(sp) < 2:
                        raise PWError("FILL requires 'selector text'")
                    sel, txt = sp[0], sp[1]
                    page.fill(sel, txt)

                elif cmd == "CLICK":
                    sel = (arg or "").strip()
                    page.click(sel)
                    with contextlib.suppress(Exception):
                        page.wait_for_load_state("domcontentloaded", timeout=10000)
                    if page.url.startswith("chrome-error://"):
                        raise PWError("navigation-error")

                elif cmd == "DUMPDOM":
                    path = (arg or "").strip()
                    if path:
                        _ensure_parent(path)
                        html = page.content()
                        pathlib.Path(path).write_text(html, encoding="utf-8")
                    else:
                        _ = page.content()

                elif cmd == "SCREENSHOT":
                    path = (arg or "").strip()
                    if not path:
                        raise PWError("SCREENSHOT needs a file path")
                    _ensure_parent(path)
                    page.screenshot(path=path, full_page=True)

                elif cmd == "SELECT":
                    m = re.match(r"^(\S+)\s+(.*)$", (arg or "").strip())
                    if not m:
                        raise PWError("SELECT needs: <selector> key=value")
                    sel, rest = m.group(1), m.group(2)
                    kv = _parse_kv(rest)
                    if   "label" in kv: page.select_option(sel, label=kv["label"])
                    elif "value" in kv: page.select_option(sel, value=kv["value"])
                    else: raise PWError("SELECT supports label= or value=")

                elif cmd == "EXPECTTEXT":
                    m = re.match(r"^'([^']+)'\s+(equals|contains)\s+(.+)$", (arg or "").strip(), re.I)
                    if not m:
                        raise PWError("EXPECTTEXT: '<selector> equals|contains <text>'")
                    sel, mode, text = m.group(1), m.group(2).lower(), m.group(3)
                    got = page.inner_text(sel).strip()
                    if mode == "equals":
                        if _norm_text(got) != _norm_text(text):
                            raise AssertionError(f"EXPECTTEXT equals fail: got='{got}' want='{text}'")
                    elif mode == "contains":
                        if _norm_text(text) not in _norm_text(got):
                            raise AssertionError(f"EXPECTTEXT contains fail: got='{got}' want-contains='{text}'")

                elif cmd == "EXPECTVALUE":
                    m = re.match(r"^(\S+)\s+(.+)$", (arg or "").strip())
                    if not m:
                        raise PWError("EXPECTVALUE: '<selector> <value>'")
                    sel, want = m.group(1), m.group(2)
                    val = page.eval_on_selector(sel, "el => el.value")
                    if _norm_text(str(val)) != _norm_text(str(want)):
                        raise AssertionError(f"EXPECTVALUE fail: got='{val}' want='{want}'")

                elif cmd == "SLEEP":
                    try:
                        ms = int((arg or "500").strip())
                    except Exception:
                        ms = 500
                    time.sleep(ms/1000.0)

                else:
                    raise PWError(f"Unsupported command: {cmd}")

            except KeyboardInterrupt:
                step_ok, err = False, "KeyboardInterrupt"
                ok_all = False
                break
            except (PWTimeout, PWError, AssertionError) as e:
                step_ok, err = False, f"{e.__class__.__name__}: {str(e)}"
                ok_all = False
            finally:
                rec = {"i": i, "cmd": cmd, "arg": arg, "ok": step_ok, "error": err, "url": page.url if page else "about:blank"}
                results.append(rec)
    return ok_all, results

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", required=True, help="Komut satırları içeren metin dosyası")
    ap.add_argument("--out", required=True, help="JSON çıktı yolu")
    ap.add_argument("--headful", action="store_true")
    ap.add_argument("--har", default=None)
    ap.add_argument("--timeout", type=int, default=None)
    args = ap.parse_args()

    with open(args.steps, "r", encoding="utf-8-sig") as f:
        text = f.read()

    steps = text.splitlines()
    ok, res = run_flow(steps, headless=(not args.headful), har_path=args.har, timeout_ms=args.timeout)

    out = {"ok": ok, "results": res}
    pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
