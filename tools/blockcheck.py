# REV: 1.1 | 2025-09-24 | Hash: dd2f32a0 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: VALIDATION | Blok başlık doğrulama & indeks | ID:PY-VAL-3T8D7W1N
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, re, json, sys
HDR_RX = re.compile(r'^\s*#\s*>>>+\s*BLOK:\s*([^|]+)\|\s*([^|]+)\|\s*ID:([A-Za-z0-9\-]+)\s*$')
END_RX = re.compile(r'^\s*#\s*<<<+\s*BLOK SONU:\s*ID:([A-Za-z0-9\-]+)\s*$')
def should_scan(fn):
    if any(part.startswith('.') for part in fn.replace('\\','/').split('/')): return False
    return fn.endswith(('.py','.js','.ts','.css','.html','.md','.yml','.yaml'))
def main():
    index, duplicates = {}, []
    for dp,_,files in os.walk('.'):
        for fn in files:
            path = os.path.join(dp, fn)
            if not should_scan(path): continue
            try:
                with open(path,'r',encoding='utf-8',errors='ignore') as f:
                    for i, line in enumerate(f, start=1):
                        m = HDR_RX.match(line)
                        if m:
                            cat = m.group(1).strip(); title = m.group(2).strip(); bid = m.group(3).strip()
                            if bid in index: duplicates.append((bid, index[bid]['file'], path))
                            index[bid] = {"file": path, "line": i, "category": cat, "title": title}
                        if END_RX.match(line): pass
            except Exception as e:
                print(f"[blockcheck] {path}: {e}", file=sys.stderr)
    os.makedirs("_otokodlama", exist_ok=True)
    with open("_otokodlama/INDEX.json","w",encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    if duplicates:
        print("[blockcheck] Yinelenen Blok ID bulundu:", file=sys.stderr)
        for bid, p1, p2 in duplicates: print(f"  {bid} : {p1}  <->  {p2}", file=sys.stderr)
        sys.exit(1)
    print(f"[blockcheck] OK. Toplam blok: {len(index)}"); return 0
if __name__ == "__main__":
    sys.exit(main())
# <<< BLOK SONU: ID:PY-VAL-3T8D7W1N
