# REV: 1.2 | 2025-09-24 | Hash: 22847e11 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.

# >>> BLOK: IMPORTS | ID:PY-LFR-IMP-7Q2W9K4B
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, sys, json, argparse, subprocess
# <<< BLOK SONU: ID:PY-LFR-IMP-7Q2W9K4B

# >>> BLOK: FILTERS | ID:PY-LFR-FLT-1A2B3C4D
ALLOWED_EXTS = {
    '.py','.ps1','.sh','.js','.ts','.css','.html','.htm','.yml','.yaml','.ini','.cfg'
}
SKIP_DIRS = {'venv','.venv','env','.env','node_modules','__pycache__','_otokodlama','var','build','dist'}
SKIP_NAMES = {'codepack_full_part01.bat'}
MAX_SIZE_BYTES = 1_000_000  # >1MB dosyaları rapora dahil etme
# <<< BLOK SONU: ID:PY-LFR-FLT-1A2B3C4D

# >>> BLOK: CORE | ID:PY-LFR-CORE-3M8D2R6Q
def git_tracked_files():
    out = subprocess.check_output(['git','ls-files'], encoding='utf-8')
    return [p for p in (line.strip() for line in out.splitlines()) if p]

def allowed_file(p: str) -> bool:
    parts = p.replace('\\','/').split('/')
    if any(seg in SKIP_DIRS for seg in parts): return False
    if os.path.basename(p) in SKIP_NAMES: return False
    ext = os.path.splitext(p)[1].lower()
    return ext in ALLOWED_EXTS

def count_lines(path):
    try:
        if os.path.getsize(path) > MAX_SIZE_BYTES:
            return -1
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return sum(1 for _ in f)
    except Exception:
        return -1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--threshold', type=int, default=650)
    ap.add_argument('--out', required=False, help='JSON çıktı yolu (örn: _otokodlama/out/xxx/longfiles.json)')
    args = ap.parse_args()

    files = [p for p in git_tracked_files() if allowed_file(p)]
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
