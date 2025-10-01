# === fix_equipment_list_r7.ps1: FINAL ROBUST SELECTOR FIX (PS 5.1, ASCII) ===
$ErrorActionPreference="Stop"

function W([string]$p,[string]$t){ Set-Content -LiteralPath $p -Value $t -Encoding ASCII }

$chg = "ops\flows\__make_baseline_admin_equipment_change.flow"
$val = "ops\flows\equipment_ui_create_validate.flow"

$base="http://127.0.0.1:8010"
$user="admin"
$pass="Admin!2345"

$LOGIN_AND_ADMIN_HOME = @"
GOTO  $base/admin/login/
WAIT  SELECTOR input[name=username]
FILL  input[name=username]  $user
FILL  input[name=password]  $pass
CLICK input[type=submit]
WAIT  SELECTOR #content-main
"@

# KR?T?K KISIM: table#result_list yerine #changelist-form bekle
$TO_LIST_PAGE = @"
GOTO  $base/admin/maintenance/equipment/_direct/

WAIT  SELECTOR #content-main

WAIT  SELECTOR #changelist-form
"@

$VALIDATE_TAIL = @"

WAIT  SELECTOR #changelist-form
# Son bekleme tablonun kendisi yerine liste i?eri?ini kontrol eder
WAIT  SELECTOR table#result_list tbody tr, p.no-results, .paginator
"@

# Basit birle?tirmeyi kullan
$head = $LOGIN_AND_ADMIN_HOME.Trim() + "`r`n" + $TO_LIST_PAGE.Trim()

if (Test-Path $chg) {
  W $chg $head
  Write-Host "[ok] rewrote: $(Split-Path $chg -Leaf) (ROBUST SELECTOR FIX)" -ForegroundColor Yellow
}

if (Test-Path $val) {
  W $val ($head + $VALIDATE_TAIL)
  Write-Host "[ok] rewrote: $(Split-Path $val -Leaf) (ROBUST SELECTOR FIX)" -ForegroundColor Yellow
}
