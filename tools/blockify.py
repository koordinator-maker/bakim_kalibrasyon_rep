# REV: 1.1 | 2025-09-25 | Hash: be15d474 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.

# >>> BLOK: IMPORTS | Blockify - otomatik blok etiketleyici | ID:PY-BLKF-IMP-8K3W1Z6Q
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, re, sys, time, argparse, subprocess, io, random
# <<< BLOK SONU: ID:PY-BLKF-IMP-8K3W1Z6Q

# >>> BLOK: UTIL | ID üretimi & yardımcılar | ID:PY-BLKF-UTL-5C9R2L7M
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # Crockford Base32
def new_id(prefix: str = "PY", length: int = 8) -> str:
    seed = int(time.time_ns()) ^ os.getpid() ^ random.getrandbits(40)
    s = ""
    n = abs(seed)
    for _ in range(length):
        s = ALPHABET[n % 32] + s
        n //= 32
    return f"{prefix}-{s}"

def git_tracked_py_files():
    out = subprocess.check_output(['git','ls-files','*.py'], encoding='utf-8', errors='ignore')
    files = [ln.strip() for ln in out.splitlines() if ln.strip()]
    # klasör filtreleri
    SKIP_DIRS = {'venv','.venv','env','.env','node_modules','__pycache__','_otokodlama','build','dist','migrations'}
    keep = []
    for p in files:
        parts = p.replace('\\','/').split('/')
        if any(seg in SKIP_DIRS for seg in parts): 
            continue
        keep.append(p)
    return keep

REV_RX = re.compile(r'^\s*(#|//|;|/\*|<!--|\{#)\s*REV:\s*\d+\.\d+\s*\|', re.IGNORECASE)
BLOK_RX = re.compile(r'^\s*#\s*>>>+\s*BLOK:', re.IGNORECASE)
IMPORT_RX = re.compile(r'^\s*(from\s+\S+\s+import\s+\S+|import\s+\S+)\s*(#.*)?$')
CLASS_MODEL_RX = re.compile(r'^\s*class\s+\w+\s*\(\s*models\.Model\b')
CLASS_VIEW_RX  = re.compile(r'^\s*class\s+\w+View\s*\(')
CLASS_FORM_RX  = re.compile(r'^\s*class\s+\w+\s*\(\s*(forms\.Form|forms\.ModelForm)\b')
DEF_VIEW_RX    = re.compile(r'^\s*def\s+\w+_view\s*\(')

def detect_category(path, lines):
    fn = os.path.basename(path).lower()
    if fn.startswith('settings'): return ('SETTINGS','Proje ayarlari')
    if fn == 'models.py': return ('MODELS','Domain modelleri')
    if fn == 'views.py': return ('VIEWS','Gorunumler')
    if fn == 'forms.py': return ('FORMS','Formlar')
    if fn == 'admin.py': return ('ADMIN','Yonetim')
    if '/management/commands/' in path.replace('\\','/'):
        return ('COMMAND','Komut')
    # icerige bakarak ipucu
    txt = ''.join(lines)
    if CLASS_MODEL_RX.search(txt): return ('MODELS','Domain modelleri')
    if CLASS_FORM_RX.search(txt):  return ('FORMS','Formlar')
    if CLASS_VIEW_RX.search(txt) or DEF_VIEW_RX.search(txt): return ('VIEWS','Gorunumler')
    return ('HELPERS','Yardimci fonksiyonlar')
# <<< BLOK SONU: ID:PY-BLKF-UTL-5C9R2L7M

# >>> BLOK: CORE | Dosya isleme | ID:PY-BLKF-CORE-3M8D2R6Q
def blockify_one(path, dry_run=False):
    with io.open(path,'r',encoding='utf-8',errors='ignore') as f:
        lines = f.readlines()
    if any(BLOK_RX.match(l) for l in lines[:80]):
        return False  # zaten bloklu
    # REV satirini bul (ilk satirda olmasi bekleniyor)
    body_start = 0
    if lines and REV_RX.match(lines[0]):
        body_start = 1

    # IMPORT bloğu araligi
    i = body_start
    # bos satirlari gect
    while i < len(lines) and lines[i].strip() == '':
        i += 1
    imp_start = i
    while i < len(lines) and (IMPORT_RX.match(lines[i]) or lines[i].strip()=='' or lines[i].strip().startswith('#')):
        # import grubu sonuna kadar ilerle (bos/comment dahil)
        i += 1
    imp_end = i

    # Kategori belirle
    category, title = detect_category(path, lines)

    # ID'ler
    imp_id = new_id('PY-IMP')
    cat_id = new_id(f'PY-{category[:3]}')

    # INSERt metinleri
    def header(cat, ttl, bid): return f"# >>> BLOK: {cat} | {ttl} | ID:{bid}\n"
    def footer(bid):           return f"# <<< BLOK SONU: ID:{bid}\n"

    new_lines = []
    # 0..body_start-1 (REV satiri dahil) oldugu gibi
    new_lines.extend(lines[:body_start])

    # IMPORT bloğu ekle
    new_lines.append(header('IMPORTS','Temel importlar', imp_id))
    new_lines.extend(lines[imp_start:imp_end])
    new_lines.append(footer(imp_id))

    # Kalan kisim ana kategori
    new_lines.append(header(category, title, cat_id))
    new_lines.extend(lines[imp_end:])
    new_lines.append(footer(cat_id))

    if not dry_run:
        with io.open(path,'w',encoding='utf-8',newline='\n') as f:
            f.writelines(new_lines)
    return True

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--limit', type=int, default=0, help='En fazla N dosya isleme (0=sinir yok)')
    args = ap.parse_args()

    changed = 0
    files = git_tracked_py_files()
    for p in files:
        try:
            ok = blockify_one(p, dry_run=args.dry_run)
            if ok:
                print(f"[blockify] {p}: bloklar eklendi")
                changed += 1
            if args.limit and changed >= args.limit:
                break
        except Exception as e:
            print(f"[blockify] {p}: HATA {e}", file=sys.stderr)
    print(f"[blockify] tamam. degisen dosya: {changed}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
# <<< BLOK SONU: ID:PY-BLKF-CORE-3M8D2R6Q
