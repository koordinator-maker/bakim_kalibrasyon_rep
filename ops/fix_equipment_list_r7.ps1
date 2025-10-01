# === fix_equipment_list_r7.ps1: FINAL /_direct/ URL FIX (PS 5.1, ASCII) ===
$ErrorActionPreference="Stop"

function W([string]$p,[string]$t){ Set-Content -LiteralPath $p -Value $t -Encoding ASCII }

$chg = "ops\flows\__make_baseline_admin_equipment_change.flow"
$val = "ops\flows\equipment_ui_create_validate.flow"

$base="http://127.0.0.1:8010"
$user="admin"
$pass="Admin!2345"

$LOGIN = @"
GOTO  $base/admin/login/
WAIT  SELECTOR input[name=username]
FILL  input[name=username]  $user
FILL  input[name=password]  $pass
CLICK input[type=submit]
WAIT  SELECTOR #content-main
"@

# Uygulaman?n zorunlu k?ld??? /_direct/ URL'si kullan?lmal?
$TO_LIST_PAGE = @"
GOTO  $base/admin/maintenance/equipment/_direct/
WAIT  SELECTOR #content-main
WAIT  SELECTOR table#result_list
"@

$VALIDATE_TAIL = @"
WAIT  SELECTOR table#result_list
WAIT  SELECTOR table#result_list tbody tr, p.no-results, .paginator
"@

$head = ($LOGIN.TrimEnd("`r","`n") + "`r`n" + $TO_LIST_PAGE.TrimStart("`r","`n"))

if (Test-Path $chg) {
  W $chg $head
  Write-Host "[ok] rewrote: $(Split-Path $chg -Leaf) (FINAL /_direct/ FIX)" -ForegroundColor Magenta
}

if (Test-Path $val) {
  W $val ($head + $VALIDATE_TAIL)
  Write-Host "[ok] rewrote: $(Split-Path $val -Leaf) (FINAL /_direct/ FIX)" -ForegroundColor Magenta
}
