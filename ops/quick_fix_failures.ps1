[CmdletBinding()]
param([string]$FlowsDir="ops\flows")
$ErrorActionPreference="Stop"

function Prepend-IfMissing([string]$path, [string]$needle, [string]$block) {
  if (-not (Test-Path $path)) { return }
  $txt = Get-Content -LiteralPath $path -Raw
  if ($txt -like ('*'+$needle+'*')) { return }
  $new = $block + "`r`n" + $txt
  Set-Content -LiteralPath $path -Value $new -Encoding ASCII
  Write-Host "[ok] patched: $([IO.Path]::GetFileName($path))" -ForegroundColor Green
}

# Ortak login
$login = @(
  'GOTO  /admin/login/',
  'WAIT  SELECTOR input[name=username]',
  'FILL  input[name=username]  admin',
  'FILL  input[name=password]  Admin!2345',
  'CLICK input[type=submit]',
  'WAIT  SELECTOR #content-main'
) -join "`r`n"

# Hedef header?lar
$addNav  = "GOTO  /admin/maintenance/equipment/add/`r`nWAIT  SELECTOR form"
$listNav = "GOTO  /admin/maintenance/equipment/`r`nWAIT  SELECTOR table#result_list"

$addFlow = Join-Path $FlowsDir "__make_baseline_admin_equipment_add.flow"
$chgFlow = Join-Path $FlowsDir "__make_baseline_admin_equipment_change.flow"

Prepend-IfMissing $addFlow "/admin/maintenance/equipment/add/" ($login + "`r`n" + $addNav)
Prepend-IfMissing $chgFlow "/admin/maintenance/equipment/"     ($login + "`r`n" + $listNav)

# Validate ak???n? net yaz (liste sayfas?n? do?rula)
$validate = Join-Path $FlowsDir "equipment_ui_create_validate.flow"
if (Test-Path $validate) {
  $lines = @()
  $lines += 'GOTO  /admin/login/?next=/admin/maintenance/equipment/'
  $lines += 'WAIT  SELECTOR input[name=username]'
  $lines += 'FILL  input[name=username]  admin'
  $lines += 'FILL  input[name=password]  Admin!2345'
  $lines += 'CLICK input[type=submit]'
  $lines += 'WAIT  SELECTOR table#result_list'
  $lines += 'WAIT  SELECTOR table#result_list tbody tr'
  Set-Content -LiteralPath $validate -Value ($lines -join "`r`n") -Encoding ASCII
  Write-Host "[ok] rewrote: equipment_ui_create_validate.flow" -ForegroundColor Green
}

Write-Host "[done] quick fixes applied." -ForegroundColor Cyan
