# REV: 1.1 | 2025-09-24 | Hash: a82325e6 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.
# >>> BLOK: GUARDRAIL | Base layout & CSS kontrol | ID:PY-GRD-8M2S4K9H
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, re, sys
ALLOWED_CLASSES = {
  "card","section-bar","section-body","field","label","help","input",
  "select","textarea","readonly","toolbar","btn","btn-primary","col-span-2"
}
def fail(msg):
    print(f"[GUARDRAIL] {msg}", file=sys.stderr); sys.exit(1)
def check_base_untouched():
    path = os.path.join("templates","base.html")
    if not os.path.exists(path): fail("templates/base.html bulunamadı.")
    with open(path, 'r', encoding='utf-8') as f: txt = f.read()
    if "<!-- GUARDRAIL: DO NOT MODIFY LAYOUT -->" not in txt:
        fail("base.html beklenen guardrail imzasını içermiyor (dosya değişmiş olabilir).")
def scan_templates():
    root = "templates"
    if not os.path.isdir(root): return
    rx_class = re.compile(r'class="([^"]+)"')
    for dp,_,files in os.walk(root):
        for fn in files:
            if not fn.endswith(('.html','.htm')): continue
            p = os.path.join(dp, fn)
            with open(p,'r',encoding='utf-8') as f: t = f.read()
            for m in rx_class.finditer(t):
                for c in m.group(1).split():
                    if c.startswith('{'): continue
                    if c not in ALLOWED_CLASSES:
                        fail(f"{p}: İzinli olmayan CSS sınıfı: {c}")
if __name__ == "__main__":
    check_base_untouched(); scan_templates(); print("[GUARDRAIL] OK")
# <<< BLOK SONU: ID:PY-GRD-8M2S4K9H
