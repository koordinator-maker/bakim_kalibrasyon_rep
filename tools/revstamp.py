# REV: 1.2 | 2025-09-24 | Hash: 1a85303f | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.

# >>> BLOK: IMPORTS | Temel importlar | ID:PY-REV-IMP-7P2XG9K1
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse, hashlib, io, os, re, sys, datetime, fnmatch, subprocess
# <<< BLOK SONU: ID:PY-REV-IMP-7P2XG9K1

# >>> BLOK: CONSTANTS | Sabitler & regex | ID:PY-REV-CST-4M8D2R6Q
HEADER_RE = re.compile(
    r'^\s*([#;/]{1,3}|<!--|/\*|\{#)\s*REV:\s*(\d+)\.(\d+)\s*\|\s*([0-9\-]{10})\s*\|\s*Hash:\s*([A-Za-z0-9]+)\s*\|\s*Parça:\s*(\d+)\/(\d+).*'
)

COMMENT_STYLES = {
    '.py':  ('# ', ''),
    '.ps1': ('# ', ''),
    '.sh':  ('# ', ''),
    '.js':  ('// ', ''),
    '.ts':  ('// ', ''),
    '.css': ('/* ', ' */'),
    '.html':('<!-- ', ' -->'),
    '.htm': ('<!-- ', ' -->'),
    '.md':  ('<!-- ', ' -->'),
    '.yml': ('# ', ''),
    '.yaml':('# ', ''),
    '.ini': ('; ', ''),
    '.cfg': ('; ', ''),
    # .json KASITLI OLARAK YOK: yorum desteklemez
}

DEFAULT_EXTS = ['.py','.ps1','.sh','.js','.ts','.css','.html','.htm','.md','.yml','.yaml','.ini','.cfg']

SKIP_DIRS = {
    'venv', '.venv', 'env', '.env', 'node_modules', '__pycache__',
    '.git', '.tox', '.mypy_cache', 'build', 'dist', 'site-packages', 'dist-packages', '_otokodlama'
}

IGNORE_FILE = '.revstampignore'
# <<< BLOK SONU: ID:PY-REV-CST-4M8D2R6Q

# >>> BLOK: IGNORE | Yoksayma mantığı | ID:PY-REV-IGN-9V5S1C8E
def load_ignores():
    pats = []
    if os.path.exists(IGNORE_FILE):
        with io.open(IGNORE_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith('#'):
                    continue
                pats.append(s)
    # _otokodlama çıktıları ile bazı yaygın klasörleri ek güvenlik için ekle
    pats.extend([
        '_otokodlama/**',
        '**/__pycache__/**',
        'venv/**', '.venv/**', 'env/**', '.env/**',
        '**/site-packages/**', '**/dist-packages/**',
        'node_modules/**', 'build/**', 'dist/**',
    ])
    return pats

IGNORE_PATTERNS = load_ignores()

def is_ignored(path: str) -> bool:
    sp = path.replace('\\','/')
    # klasör segmenti bazlı hızlı skip
    if any(seg in SKIP_DIRS for seg in sp.split('/')):
        return True
    # desen bazlı skip
    for pat in IGNORE_PATTERNS:
        if fnmatch.fnmatch(sp, pat):
            return True
    return False
# <<< BLOK SONU: ID:PY-REV-IGN-9V5S1C8E

# >>> BLOK: IO | Dosya okuma-yazma & yardımcılar | ID:PY-REV-IO-6T1B7N4L
def read_file(path):
    with io.open(path, 'r', encoding='utf-8', errors='ignore') as f:
        return f.read()

def write_file(path, text):
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)

def comment_style_for(path):
    ext = os.path.splitext(path)[1].lower()
    return COMMENT_STYLES.get(ext, ('# ', ''))  # bilinmeyene # yorum uygular (metin dosyaları için güvenli)

def compute_body_hash(text):
    h = hashlib.sha1(text.encode('utf-8')).hexdigest()
    return h[:8]
# <<< BLOK SONU: ID:PY-REV-IO-6T1B7N4L

# >>> BLOK: HEADER | REV başlığı işlemleri | ID:PY-REV-HDR-3K9E2U5P
def parse_existing_header(first_line):
    m = HEADER_RE.match(first_line.strip())
    if not m:
        return None
    return dict(
        major=int(m.group(2)),
        minor=int(m.group(3)),
        date=m.group(4),
        hash=m.group(5),
        part=f"{m.group(6)}/{m.group(7)}"
    )

def format_header(prefix, suffix, major, minor, date_s, hash_s, part_s):
    base = f"REV: {major}.{minor} | {date_s} | Hash: {hash_s} | Parça: {part_s}"
    if suffix:
        return f"{prefix}{base}{suffix}\n"
    return f"{prefix}{base}\n"
# <<< BLOK SONU: ID:PY-REV-HDR-3K9E2U5P

# >>> BLOK: PROCESS | Tek dosyayı işleme | ID:PY-REV-PRC-1R7S8Q2A
def process_file(path, bump_major=False, part_override=None, quiet=False):
    raw = read_file(path)
    lines = raw.splitlines(True)
    prefix, suffix = comment_style_for(path)

    existing = parse_existing_header(lines[0]) if lines else None

    # gövde (header hariç)
    if existing:
        body = "".join(lines[1:])
    else:
        body = "".join(lines)

    new_hash = compute_body_hash(body)
    today = datetime.date.today().isoformat()
    part = part_override or (existing['part'] if existing else '1/1')

    if existing:
        changed = (new_hash != existing['hash'])
        major = existing['major']
        minor = existing['minor']
        if changed:
            if bump_major:
                major += 1
                minor = 0
            else:
                minor += 1
        header = format_header(prefix, suffix, major, minor, today, new_hash, part)
        new_text = header + body
        updated = changed or (existing['date'] != today) or bool(part_override)
    else:
        header = format_header(prefix, suffix, 1, 0, today, new_hash, part)
        new_text = header + body
        updated = True

    if updated:
        write_file(path, new_text)
        if not quiet:
            print(f"[REV] {path}: güncellendi (hash={new_hash})")
    else:
        if not quiet:
            print(f"[REV] {path}: değişiklik yok (hash sabit)")

    # 650+ satır uyarısı (sadece proje dosyalarında anlamlı)
    total_lines = new_text.count('\n') + 1
    if total_lines > 650 and not quiet:
        print(f"[UYARI] {path}: {total_lines} satır (>650). Bölmeyi düşünün (Parça i/N).")
    return 0

def should_skip(path):
    sp = path.replace('\\','/')
    if is_ignored(sp):
        return True
    name = os.path.basename(path).lower()
    if name.startswith('.'):
        return True
    # kaba binary kontrolü
    try:
        with open(path, 'rb') as f:
            chunk = f.read(2048)
        if b'\x00' in chunk:
            return True
    except:
        return True
    return False
# <<< BLOK SONU: ID:PY-REV-PRC-1R7S8Q2A

# >>> BLOK: WALK | Dizin tarama | ID:PY-REV-WLK-8C3M0H5V
def walk_and_process(paths, patterns, **opts):
    ok = 0
    for base in paths:
        # Tek tek dosya verilmişse
        if os.path.isfile(base):
            if not should_skip(base) and (not patterns or any(base.endswith(p) for p in patterns)):
                try:
                    process_file(base, **opts)
                except Exception as e:
                    print(f"[HATA] {base}: {e}", file=sys.stderr); ok = 1
            continue
        # Klasörse yürü
        for dirpath, _, filenames in os.walk(base):
            if is_ignored(dirpath):
                continue
            for fn in filenames:
                path = os.path.join(dirpath, fn)
                if should_skip(path):
                    continue
                if patterns and not any(path.endswith(p) for p in patterns):
                    continue
                try:
                    process_file(path, **opts)
                except Exception as e:
                    print(f"[HATA] {path}: {e}", file=sys.stderr); ok = 1
    return ok
# <<< BLOK SONU: ID:PY-REV-WLK-8C3M0H5V

# >>> BLOK: MAIN | Argümanlar & giriş noktası | ID:PY-REV-MAIN-2N6B4J8Y
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='*', default=['.'], help='Kök klasör(ler) veya dosyalar')
    ap.add_argument('--ext', nargs='*', default=DEFAULT_EXTS, help='İşlenecek uzantılar')
    ap.add_argument('--bump-major', action='store_true', help='Değişiklikte major versiyonu artır')
    ap.add_argument('--part', help='i/N formatında parça bilgisi (örn. 2/3)')
    ap.add_argument('--quiet', action='store_true', help='Sessiz çıktı')
    ap.add_argument('--tracked', action='store_true', help='Sadece git’te takipli dosyaları işle')

    args = ap.parse_args()

    if args.tracked:
        try:
            out = subprocess.check_output(['git', 'ls-files'], encoding='utf-8')
            paths = [p for p in (line.strip() for line in out.splitlines()) if p]
        except Exception as e:
            print(f"[REV] git ls-files hatası: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        paths = args.paths

    sys.exit(
        walk_and_process(
            paths, args.ext,
            bump_major=args.bump_major,
            part_override=args.part,
            quiet=args.quiet
        )
    )

if __name__ == '__main__':
    main()
# <<< BLOK SONU: ID:PY-REV-MAIN-2N6B4J8Y
