[CmdletBinding()]
param(
  [string]$FlowsDir = "ops\flows",
  [string]$User     = "admin",
  [string]$Pass     = "Admin!2345"
)
$ErrorActionPreference = "Stop"

function Read-Text([string]$p){ Get-Content -LiteralPath $p -Raw }
function Write-Text([string]$p,[string]$t){ Set-Content -LiteralPath $p -Value $t -Encoding ASCII }
function Strip-Lines([string]$txt,[string]$pat){
  [regex]::Replace($txt,$pat,"",[System.Text.RegularExpressions.RegexOptions]::Multiline)
}
function Prepend([string]$txt,[string]$block){ $block + "`r`n" + $txt }

# Sa?lam login blo?u
$login  = "GOTO  /admin/login/`r`n"
$login += "WAIT  SELECTOR input[name=username]`r`n"
$login += ("FILL  input[name=username]  {0}`r`n" -f $User)
$login += ("FILL  input[name=password]  {0}`r`n" -f $Pass)
$login += "CLICK input[type=submit]`r`n"
$login += "WAIT  SELECTOR #content-main"

# Hedef dosyalar
$addFlow = Join-Path $FlowsDir "__make_baseline_admin_equipment_add.flow"
$chgFlow = Join-Path $FlowsDir "__make_baseline_admin_equipment_change.flow"
$dbgFlow = Join-Path $FlowsDir "debug_equipment_change.flow"
$valFlow = Join-Path $FlowsDir "equipment_ui_create_validate.flow"

# Ortak temizleyici
function Clean-Body([string]$body){
  $b = $body
  $b = Strip-Lines $b '^\s*GOTO\s+/admin/login/.*\r?$'
  $b = Strip-Lines $b '^\s*FILL\s+input\[name=username\].*\r?$'
  $b = Strip-Lines $b '^\s*FILL\s+input\[name=password\].*\r?$'
  $b = Strip-Lines $b '^\s*CLICK\s+input\[type=submit\].*\r?$'
  $b = Strip-Lines $b '^\s*WAIT\s+SELECTOR-OR[^\r\n]*\r?$'
  $b = Strip-Lines $b '^\s*WAIT\s+URL\s+CONTAINS[^\r\n]*\r?$'
  $b
}

# 1) ADD baseline: add formunu bekle
if (Test-Path $addFlow) {
  $t = Read-Text $addFlow
  $t = Clean-Body $t
  $hdr  = $login + "`r`n"
  $hdr += "GOTO  /admin/maintenance/equipment/add/`r`n"
  $hdr += "WAIT  SELECTOR form"
  # yanl?? tablo bekleyen sat?r? form ile de?i?tir
  $t = [regex]::Replace($t,'(?m)^\s*WAIT\s+SELECTOR\s+table#result_list\s*$','WAIT  SELECTOR form')
  $t = Prepend $t $hdr
  Write-Text $addFlow $t
  Write-Host "[ok] patched: $(Split-Path $addFlow -Leaf)" -ForegroundColor Green
}

# 2) CHANGE baseline: liste tablosunu bekle
if (Test-Path $chgFlow) {
  $t = Read-Text $chgFlow
  $t = Clean-Body $t
  $hdr  = $login + "`r`n"
  $hdr += "GOTO  /admin/maintenance/equipment/`r`n"
  $hdr += "WAIT  SELECTOR #content-main`r`n"
  $hdr += "WAIT  SELECTOR table#result_list"
  $t = Prepend $t $hdr
  Write-Text $chgFlow $t
  Write-Host "[ok] patched: $(Split-Path $chgFlow -Leaf)" -ForegroundColor Green
}

# 3) DEBUG flow: CHANGE ile ayn? giri?
if (Test-Path $dbgFlow) {
  $t = Read-Text $dbgFlow
  $t = Clean-Body $t
  $hdr  = $login + "`r`n"
  $hdr += "GOTO  /admin/maintenance/equipment/`r`n"
  $hdr += "WAIT  SELECTOR #content-main`r`n"
  $hdr += "WAIT  SELECTOR table#result_list"
  $t = Prepend $t $hdr
  Write-Text $dbgFlow $t
  Write-Host "[ok] patched: $(Split-Path $dbgFlow -Leaf)" -ForegroundColor Green
}

# 4) VALIDATE: sade ve sa?lam
if (Test-Path $valFlow) {
  $lines = @()
  $lines += 'GOTO  /admin/login/?next=/admin/maintenance/equipment/'
  $lines += 'WAIT  SELECTOR input[name=username]'
  $lines += ("FILL  input[name=username]  {0}" -f $User)
  $lines += ("FILL  input[name=password]  {0}" -f $Pass)
  $lines += 'CLICK input[type=submit]'
  $lines += 'WAIT  SELECTOR #content-main'
  $lines += 'WAIT  SELECTOR table#result_list'
  $lines += 'WAIT  SELECTOR table#result_list tbody tr'
  Write-Text $valFlow ($lines -join "`r`n")
  Write-Host "[ok] rewrote: $(Split-Path $valFlow -Leaf)" -ForegroundColor Green
}

Write-Host "[done] admin equipment baselineleri stabilize edildi." -ForegroundColor Cyan
