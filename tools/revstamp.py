# REV: 1.1 | 2025-09-25 | Hash: 127a41f3 | Parça: 1/1
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Revizyon Takip Sistemi - Otokodlama
- REV satırı ekler/günceller
- Gövde hash'ine göre değişikliği algılar
- 650 satır sınırı için uyarır
- "Parça" alanını 1/1 olarak bırakır; istenirse --part i/N ile geçersiz kılınır
"""

import argparse, hashlib, io, os, re, sys, datetime

# Tüm yorum türlerini yakala: #, //, ;, /* */, {# #}, <!-- -->
HEADER_RE = re.compile(
    r'^\s*(?:#|//|;|/\*|{#|<!--)\s*'            # açılış
    r'REV:\s*(\d+)\.(\d+)\s*\|\s*'              # 1: major, 2: minor
    r'([0-9]{4}-[0-9]{2}-[0-9]{2})\s*\|\s*'     # 3: tarih YYYY-MM-DD
    r'Hash:\s*([A-Za-z0-9]+)\s*\|\s*'           # 4: hash
    r'Parça:\s*(\d+)\/(\d+)\s*'                 # 5,6: parça
    r'(?:\*/|#}|-->)?\s*$'                      # kapanış (opsiyonel)
)

COMMENT_PREFIXES = {
    '.py': '# ', '.sh': '# ', '.ps1': '# ', '.js': '// ', '.ts': '// ',
    '.css': '/* ', '.html': '{# ', '.htm': '{# ', '.vue': '<!-- ', '.json': '// ',
    '.md': '<!-- ', '.yml': '# ', '.yaml': '# ', '.ini': '; ', '.cfg': '; ',
}
COMMENT_SUFFIX = {
    '.css': ' */', '.html': ' #}', '.htm': ' #}', '.vue': ' -->', '.md': ' -->', '.json': '',
}

def detect_prefix_suffix(path):
    ext = os.path.splitext(path)[1].lower()
    return COMMENT_PREFIXES.get(ext, '# '), COMMENT_SUFFIX.get(ext, '')

def compute_body_hash(text):
    # EOL normalize ederek hashle -> CRLF/LF dalgalanmasını sabitler
    norm = text.replace('\r\n', '\n').replace('\r', '\n')
    return hashlib.sha1(norm.encode('utf-8')).hexdigest()[:8]

def read_file(path):
    # utf-8-sig -> varsa baştaki BOM’u otomatik sök
    with io.open(path, 'r', encoding='utf-8-sig', errors='ignore') as f:
        return f.read()

def write_file(path, text):
    # Yazarken LF bırak (gitattributes zaten EOL’ü yönetiyor)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)

def format_header(prefix, suffix, rev_major, rev_minor, date_s, hash_s, part_s):
    base = f"REV: {rev_major}.{rev_minor} | {date_s} | Hash: {hash_s} | Parça: {part_s}"
    return f"{prefix}{base}{suffix}\n" if suffix else f"{prefix}{base}\n"

def parse_existing_header(first_line):
    m = HEADER_RE.match(first_line.strip())
    if not m:
        return None
    return {
        'major': int(m.group(1)),
        'minor': int(m.group(2)),
        'date':  m.group(3),
        'hash':  m.group(4),
        'part':  f"{m.group(5)}/{m.group(6)}",
    }

def process_file(path, bump_major=False, part_override=None, quiet=False):
    raw = read_file(path)
    lines = raw.splitlines(True)  # satır sonlarını koru

    existing = parse_existing_header(lines[0]) if lines else None

    # gövde (mevcut başlığı hariç tut)
    body = "".join(lines[1:]) if existing else "".join(lines)

    new_hash = compute_body_hash(body)
    today   = datetime.date.today().isoformat()
    part    = part_override or (existing['part'] if existing else '1/1')

    if existing:
        changed = (new_hash != existing['hash'])
        major, minor = existing['major'], existing['minor']
        if changed:
            if bump_major:
                major += 1; minor = 0
            else:
                minor += 1
        header   = format_header(*detect_prefix_suffix(path), major, minor, today, new_hash, part)
        new_text = header + body
        updated  = changed or (existing['date'] != today) or bool(part_override)
    else:
        # ilk kez damgalama
        header   = format_header(*detect_prefix_suffix(path), 1, 0, today, new_hash, part)
        new_text = header + body
        updated  = True

    if updated:
        write_file(path, new_text)
        if not quiet:
            print(f"[REV] {path}: güncellendi (hash={new_hash})")
    else:
        if not quiet:
            print(f"[REV] {path}: değişiklik yok (hash sabit)")

    # 650 satır uyarısı (bilgilendirme)
    total_lines = new_text.count('\n') + 1
    if total_lines > 650 and not quiet:
        print(f"[UYARI] {path}: {total_lines} satır (>650). Bölmeyi düşünün (Parça i/N).")
    return 0

def should_skip(path):
    p = path.replace('\\', '/').lower()

    # Repo-dışı / üretilen / sanal ortam / cache klasörleri
    skip_dirs = (
        '/.git/', '/_otokodlama/', '/venv/', '/.venv/',
        '/node_modules/', '/__pycache__/', '/.mypy_cache/',
        '/.pytest_cache/', '/dist/', '/build/', '/.tox/'
    )
    if any(s in p for s in skip_dirs):
        return True

    # Tekil dosya istisnaları
    if p.endswith('/var/bootreport.json'):
        return True

    # Kaba binary kontrolü
    try:
        with open(path, 'rb') as f:
            if b'\x00' in f.read(2048):
                return True
    except:
        return True

    return False

def walk_and_process(roots, patterns, **opts):
    rc = 0
    for base in roots:
        for dirpath, _, filenames in os.walk(base):
            for fn in filenames:
                path = os.path.join(dirpath, fn)
                if should_skip(path):
                    continue
                if patterns and not any(path.lower().endswith(p) for p in patterns):
                    continue
                try:
                    process_file(path, **opts)
                except Exception as e:
                    print(f"[HATA] {path}: {e}", file=sys.stderr)
                    rc = 1
    return rc

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='*', default=['.'], help='Kök klasör(ler)')
    ap.add_argument('--ext', nargs='*', default=['.py','.html','.css','.js','.ts','.md','.yml','.yaml','.json','.ini','.cfg'])
    ap.add_argument('--bump-major', action='store_true')
    ap.add_argument('--part', help='i/N formatında parçayı zorla, ör: 2/3')
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()
    sys.exit(
        walk_and_process(
            args.paths, args.ext,
            bump_major=args.bump_major,
            part_override=args.part,
            quiet=args.quiet
        )
    )

if __name__ == '__main__':
    main()
