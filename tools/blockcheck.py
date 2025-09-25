# REV: 1.3 | 2025-09-25 | Hash: e7eb6449 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: VALIDATION | Blok başlık doğrulama & indeks (tracked+debug) | ID:PY-VAL-DBG-4T8D7W1N
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, re, json, sys, argparse, subprocess

HDR_RX = re.compile(
    r'^\s*#\s*>>>+\s*BLOK:\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*ID\s*:\s*([A-Za-z0-9\-]+)\s*(?:#.*)?$'
)
END_RX = re.compile(r'^\s*#\s*<<<+\s*BLOK SONU:\s*ID\s*:\s*([A-Za-z0-9\-]+)\s*(?:#.*)?$')

def should_scan(fn):
    if any(part.startswith('.') for part in fn.replace('\\','/').split('/')): return False
    return fn.endswith(('.py','.js','.ts','.css','.html','.md','.yml','.yaml'))

def git_tracked():
    try:
        out = subprocess.check_output(['git','ls-files'], encoding='utf-8')
        return [p for p in (ln.strip() for ln in out.splitlines()) if p]
    except Exception:
        return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tracked', action='store_true', help='Sadece git takipli dosyalar')
    ap.add_argument('--debug', action='store_true', help='Eşleşmeleri stdout\'a yaz')
    args = ap.parse_args()

    files = []
    if args.tracked:
        tracked = git_tracked()
        files = [p for p in tracked if should_scan(p)]
    else:
        for dp,_,fls in os.walk('.'):
            if '/.git' in dp.replace('\\','/'): continue
            for fn in fls:
                p = os.path.join(dp, fn)
                if should_scan(p): files.append(p)

    index, duplicates = {}, []
    for path in files:
        try:
            with open(path,'r',encoding='utf-8',errors='ignore') as f:
                for i, line in enumerate(f, start=1):
                    m = HDR_RX.match(line)
                    if m:
                        cat = m.group(1).strip()
                        title = m.group(2).strip()
                        bid = m.group(3).strip()
                        if bid in index:
                            duplicates.append((bid, index[bid]['file'], path))
                        index[bid] = {"file": path, "line": i, "category": cat, "title": title}
                        if args.debug:
                            print(f"[match] {path}:{i}  {cat} | {title} | ID:{bid}")
        except Exception as e:
            print(f"[blockcheck] {path}: {e}", file=sys.stderr)

    os.makedirs("_otokodlama", exist_ok=True)
    with open("_otokodlama/INDEX.json","w",encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    if duplicates:
        print("[blockcheck] Yinelenen Blok ID bulundu:", file=sys.stderr)
        for bid, p1, p2 in duplicates:
            print(f"  {bid} : {p1}  <->  {p2}", file=sys.stderr)
        sys.exit(1)

    print(f"[blockcheck] OK. Toplam blok: {len(index)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
# <<< BLOK SONU: ID:PY-VAL-DBG-4T8D7W1N
