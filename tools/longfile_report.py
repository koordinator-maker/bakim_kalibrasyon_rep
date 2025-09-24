# REV: 1.1 | 2025-09-24 | Hash: b4e8d9aa | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.

# >>> BLOK: IMPORTS | ID:PY-LFR-IMP-7Q2W9K4B
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, sys, json, argparse, subprocess
# <<< BLOK SONU: ID:PY-LFR-IMP-7Q2W9K4B

# >>> BLOK: CORE | ID:PY-LFR-CORE-3M8D2R6Q
def git_tracked_files():
    out = subprocess.check_output(['git','ls-files'], encoding='utf-8')
    return [p for p in (line.strip() for line in out.splitlines()) if p]

def count_lines(path):
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return sum(1 for _ in f)
    except Exception:
        return -1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--threshold', type=int, default=650)
    ap.add_argument('--out', required=False, help='JSON çıktı yolu (örn: _otokodlama/out/xxx/longfiles.json)')
    args = ap.parse_args()

    files = git_tracked_files()
    rows = []
    for p in files:
        n = count_lines(p)
        if n >= 0 and n > args.threshold:
            parts = (n + args.threshold - 1) // args.threshold
            rows.append({"file": p, "lines": n, "suggested_parts": parts})

    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)

    if rows:
        print(f"[longfile_report] >{args.threshold} satır dosyalar ({len(rows)} adet):")
        for r in rows:
            print(f"  - {r['file']}: {r['lines']} satır → öneri Parça 1/{r['suggested_parts']}")
    else:
        print(f"[longfile_report] Limit {args.threshold} üzeri dosya yok.")

if __name__ == "__main__":
    main()
# <<< BLOK SONU: ID:PY-LFR-CORE-3M8D2R6Q
