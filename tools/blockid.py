# REV: 1.1 | 2025-09-25 | Hash: ea809379 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: SETUP | Benzersiz blok kodu üretici | ID:PY-SET-Q6R5V2JK
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Benzersiz blok kodu üretimi (Crockford Base32 kısa ID)
"""
import os, time, random, argparse
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # O/I/L/U yok; okuması kolay
def base32(n: int, length: int = 10) -> str:
    s = ""
    for _ in range(length):
        s = ALPHABET[n % 32] + s; n //= 32
    return s
def new_id(prefix: str = "PY") -> str:
    seed = int(time.time_ns()) ^ os.getpid() ^ random.getrandbits(40)
    return f"{prefix}-{base32(abs(seed), length=8)}"
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-n','--count', type=int, default=1)
    ap.add_argument('--prefix', default='PY', help='Örn: PY, JS, CSS, API')
    args = ap.parse_args()
    for _ in range(args.count):
        print(new_id(args.prefix))
if __name__ == "__main__":
    main()
# <<< BLOK SONU: ID:PY-SET-Q6R5V2JK
