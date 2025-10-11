Rev: 2025-09-30 19:21 r1
#!/usr/bin/env python3
import csv, json, re, sys, argparse, pathlib

ALLOWED_TYPES = {"feature","bugfix","refactor","test","chore"}
ALLOWED_PRI = {"P0","P1","P2","P3"}
ALLOWED_SIZE = {"XS","S","M","L","XL"}

def slugify(s:str)->str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9\-_\sğüşöçıİĞÜŞÖÇ]", "", s, flags=re.IGNORECASE)
    s = s.replace("ı","i").replace("İ","i")
    s = s.replace("ç","c").replace("Ç","c")
    s = s.replace("ğ","g").replace("Ğ","g")
    s = s.replace("ö","o").replace("Ö","o")
    s = s.replace("ş","s").replace("Ş","s")
    s = s.replace("ü","u").replace("Ü","u")
    s = re.sub(r"\s+","-", s).strip("-")
    return s

def read_csv(path):
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        rdr = csv.DictReader(f)
        rows = [ {k.strip(): (v or "").strip() for k,v in row.items()} for row in rdr ]
    return rows

def validate(rows):
    errs, warns = [], []
    ids = set()
    required = ["id","title","area","type","priority","size","description","acceptance_criteria"]
    for i,row in enumerate(rows, start=2):  # header + 1-based index
        miss = [k for k in required if not row.get(k)]
        if miss:
            errs.append(f"Satır {i}: Zorunlu alan yok: {', '.join(miss)}")
        rid = row.get("id","")
        if rid in ids:
            errs.append(f"Satır {i}: id tekrarı: {rid}")
        else:
            ids.add(rid)
        if row.get("type") and row["type"] not in ALLOWED_TYPES:
            errs.append(f"Satır {i}: type geçersiz: {row['type']}")
        if row.get("priority") and row["priority"] not in ALLOWED_PRI:
            errs.append(f"Satır {i}: priority geçersiz: {row['priority']}")
        if row.get("size") and row["size"] not in ALLOWED_SIZE:
            errs.append(f"Satır {i}: size geçersiz: {row['size']}")
        if not row.get("acceptance_criteria"):
            warns.append(f"Satır {i}: acceptance_criteria boş görünüyor")
    return errs, warns

def transform(rows):
    tasks = []
    for r in rows:
        labels = [s.strip() for s in (r.get("labels","") or "").split(",") if s.strip()]
        ac = [s.strip() for s in (r.get("acceptance_criteria","") or "").split(";") if s.strip()]
        branch = f"auto/{r['id']}-{slugify(r['title'])}"
        tasks.append({
            "id": r["id"],
            "title": r["title"],
            "area": r["area"],
            "type": r["type"],
            "priority": r["priority"],
            "size": r["size"],
            "labels": labels,
            "description": r["description"],
            "acceptance_criteria": ac,
            "branch_name": branch
        })
    return tasks

def write_md(tasks, path):
    lines = []
    lines.append("| id | title | type | pri | size | area | labels |")
    lines.append("|----|-------|------|-----|------|------|--------|")
    for t in tasks:
        lines.append(f"| {t['id']} | {t['title']} | {t['type']} | {t['priority']} | {t['size']} | {t['area']} | {', '.join(t['labels'])} |")
    lines.append("\n---\n")
    for t in tasks:
        lines.append(f"## {t['id']} — {t['title']}")
        lines.append(f"**Area:** `{t['area']}`  |  **Type:** `{t['type']}`  |  **Priority:** `{t['priority']}`  |  **Size:** `{t['size']}`")
        lines.append("")
        lines.append(t["description"])
        lines.append("")
        if t["acceptance_criteria"]:
            lines.append("**Acceptance Criteria:**")
            for a in t["acceptance_criteria"]:
                lines.append(f"- {a}")
        lines.append("")
    pathlib.Path(path).write_text("\n".join(lines), encoding="utf-8")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", help="input CSV (UTF-8)")
    ap.add_argument("--out-json", default="plan/tasks.json")
    ap.add_argument("--out-md", default="plan/tasks.md")
    args = ap.parse_args()

    rows = read_csv(args.csv)
    errs, warns = validate(rows)
    if warns:
        print("\n".join(f"[WARN] {w}" for w in warns), file=sys.stderr)
    if errs:
        print("\n".join(f"[ERR]  {e}" for e in errs), file=sys.stderr)
        sys.exit(1)

    tasks = transform(rows)
    pathlib.Path(args.out_json).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(args.out_json).write_text(json.dumps(tasks, ensure_ascii=False, indent=2), encoding="utf-8")
    write_md(tasks, args.out_md)
    print(f"[ok] JSON → {args.out_json}")
    print(f"[ok] Markdown → {args.out_md}")
    print(f"[ok] {len(tasks)} görev dönüştürüldü.")

if __name__ == "__main__":
    main()
