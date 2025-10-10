import ast, sys
p = r"tools/pw_flow.py"
with open(p, "r", encoding="utf-8") as f:
    src = f.read()
try:
    ast.parse(src)
except SyntaxError as e:
    print("PY-SYNTAX-ERROR", e.lineno, e.msg)
    lines = src.splitlines()
    s = max(0, e.lineno-5); e2 = min(len(lines), e.lineno+5)
    for i in range(s, e2):
        print(f"{i+1:4} | {lines[i]}")
    sys.exit(1)
else:
    print("PY-SYNTAX-OK")
