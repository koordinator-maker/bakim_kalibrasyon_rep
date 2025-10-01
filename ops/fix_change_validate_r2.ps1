# Rev: r2 ? inline yorumlar? kald?r, robust selector beklemeleri ekle
param(
  [string]$Base = "http://127.0.0.1:8010",
  [string]$User = "admin",
  [string]$Pass = "Admin!2345"
)
$ErrorActionPreference="Stop"

function W($p,$t){ Set-Content -LiteralPath $p -Value $t -Encoding ASCII }

$chg = "ops\flows\__make_baseline_admin_equipment_change.flow"
$val = "ops\flows\equipment_ui_create_validate.flow"

# Tek sat?rl?k bekleme hedefleri (OR i?in virg?l kullan?yoruz)
$LIST_ANY = " #changelist,form#changelist-form,table#result_list "
$TABLE_OR = " table#result_list,form#changelist-form table "

$loginNext = "$Base/admin/login/?next=/admin/maintenance/equipment/_direct/"

$CHANGE = @"
GOTO  $loginNext
WAIT  SELECTOR input[name=username]
FILL  input[name=username]  $User
FILL  input[name=password]  $Pass
CLICK input[type=submit]
WAIT  SELECTOR #content-main
GOTO  $Base/admin/maintenance/equipment/_direct/
WAIT  SELECTOR #content-main
WAIT  SELECTOR$LIST_ANY
WAIT  SELECTOR$TABLE_OR
"@

$VALIDATE = @"
GOTO  $loginNext
WAIT  SELECTOR input[name=username]
FILL  input[name=username]  $User
FILL  input[name=password]  $Pass
CLICK input[type=submit]
WAIT  SELECTOR #content-main
GOTO  $Base/admin/maintenance/equipment/_direct/
WAIT  SELECTOR #content-main
WAIT  SELECTOR$LIST_ANY
WAIT  SELECTOR$TABLE_OR
"@

if (Test-Path $chg) { W $chg $CHANGE; Write-Host "[ok] rewrote: $(Split-Path $chg -Leaf)" -ForegroundColor Green }
if (Test-Path $val) { W $val $VALIDATE; Write-Host "[ok] rewrote: $(Split-Path $val -Leaf)" -ForegroundColor Green }
