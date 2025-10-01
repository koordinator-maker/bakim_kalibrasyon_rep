[CmdletBinding()]
param(
  [string]$Base = "http://127.0.0.1:8010",
  [string]$User = "admin",
  [string]$Pass = "Admin!2345"
)
$ErrorActionPreference = "Stop"

function W([string]$p,[string]$t){ Set-Content -LiteralPath $p -Value $t -Encoding ASCII }

$chg = "ops\flows\__make_baseline_admin_equipment_change.flow"
$val = "ops\flows\equipment_ui_create_validate.flow"

$LOGIN = @"
GOTO  $Base/admin/login/
WAIT  SELECTOR input[name=username]
FILL  input[name=username]  $User
FILL  input[name=password]  $Pass
CLICK input[type=submit]
WAIT  SELECTOR #content-main
"@

# Admin index -> Maintenance -> Equipment linkini s?n?fla bul (attribute yok, '/' yok)
# Django admin: <tr class="model-equipment"> i?inde link bulunur
$TO_LIST = @"
GOTO  $Base/admin/
WAIT  SELECTOR #content-main
WAIT  SELECTOR .model-equipment a
CLICK .model-equipment a
WAIT  SELECTOR #changelist
WAIT  SELECTOR .object-tools a.addlink
"@

if (Test-Path $chg) {
  W $chg ($LOGIN + $TO_LIST)
  Write-Host "[ok] rewrote: $(Split-Path $chg -Leaf)" -ForegroundColor Green
}
if (Test-Path $val) {
  W $val ($LOGIN + $TO_LIST)
  Write-Host "[ok] rewrote: $(Split-Path $val -Leaf)" -ForegroundColor Green
}
