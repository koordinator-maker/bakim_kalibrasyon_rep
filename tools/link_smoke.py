# -*- coding: utf-8 -*-
import sys, json, argparse
from urllib.parse import urljoin, urlsplit, urlunsplit
from html.parser import HTMLParser
from collections import deque
from playwright.sync_api import sync_playwright

class AnchorParser(HTMLParser):
    def __init__(self): 
        super().__init__(); self.links=[]
    def handle_starttag(self, tag, attrs):
        if tag != "a": return
        href = None
        for k,v in attrs:
            if k == "href": href=v; break
        if href: self.links.append(href)

def normalize(current, href):
    if not href: return None
    h = href.strip()
    if not h or h[0] == "#" or h.startswith(("mailto:","tel:","javascript:")):
        return None
    url = urljoin(current, h)
    u = urlsplit(url)
    # fragment'i at
    return urlunsplit((u.scheme, u.netloc, u.path, u.query, ""))

def in_scope(url, origin, path_prefix):
    u = urlsplit(url)
    if f"{u.scheme}://{u.netloc}" != origin: return False
    if path_prefix and not u.path.startswith(path_prefix): return False
    return True

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)               # http://127.0.0.1:8010
    ap.add_argument("--start", required=True)              # /admin/...
    ap.add_argument("--out", required=True)
    ap.add_argument("--depth", type=int, default=1)
    ap.add_argument("--limit", type=int, default=200)
    ap.add_argument("--path-prefix", default=None)
    ap.add_argument("--login-path", default="/admin/login/")
    ap.add_argument("--username", default=None)
    ap.add_argument("--password", default=None)
    ap.add_argument("--timeout", type=int, default=20000)
    args = ap.parse_args()

    base = args.base.rstrip("/")
    start_url = urljoin(base + "/", args.start)
    base_u = urlsplit(base)
    origin = f"{base_u.scheme}://{base_u.netloc}"

    # path prefix => verilmemişse start URL'in klasörü
    if args.path_prefix:
        path_prefix = args.path_prefix
    else:
        su = urlsplit(start_url)
        pp = su.path
        if not pp.endswith("/"): pp = pp.rsplit("/",1)[0] + "/"
        path_prefix = pp

    results = { "ok": True, "start": start_url, "depth": args.depth,
                "limit": args.limit, "path_prefix": path_prefix, "checked": [] }
    seen, q = set(), deque()
    q.append((start_url,0)); seen.add(start_url)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(base_url=base)
        page = context.new_page()
        page.set_default_timeout(args.timeout)
        page.set_default_navigation_timeout(args.timeout)

        # Admin login (varsa)
        if args.username and args.password and args.login_path:
            try:
                page.goto(args.login_path)
                page.fill("input#id_username", args.username)
                page.fill("input#id_password", args.password)
                page.click("input[type=submit]")
                page.wait_for_selector("#user-tools a[href$='/logout/']", timeout=args.timeout)
            except Exception:
                # login başarısız olsa da devam edip public linkleri tarayabiliriz
                pass

        rq = context.request
        count = 0
        while q and count < args.limit:
            url, d = q.popleft()
            status, text = 0, ""
            try:
                resp = rq.get(url)
                status = resp.status
                ctype = resp.headers.get("content-type","")
                if "text/html" in ctype:
                    text = resp.text()
            except Exception:
                pass

            results["checked"].append({"url": url, "status": status})
            if status >= 400 or status == 0:
                results["ok"] = False

            count += 1
            if d < args.depth and text:
                parser = AnchorParser()
                try: parser.feed(text)
                except Exception: pass
                for href in parser.links:
                    nu = normalize(url, href)
                    if not nu: continue
                    if not in_scope(nu, origin, path_prefix): continue
                    if nu not in seen:
                        seen.add(nu); q.append((nu, d+1))

        context.close(); browser.close()

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    bad = [x for x in results["checked"] if x["status"] >= 400 or x["status"] == 0]
    print(f"[link-smoke] checked={len(results['checked'])} bad={len(bad)} scope_prefix={path_prefix}")
    if bad:
        for b in bad[:10]:
            print(f"  {b['status']:>3} {b['url']}")
    sys.exit(0 if results["ok"] else 2)

if __name__ == "__main__":
    main()
