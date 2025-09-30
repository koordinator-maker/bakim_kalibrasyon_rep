# Rev: 2025-10-01 postgen patch (fixed)
param(
  [string]$FlowsDir = "ops\flows",
  [string]$Backlog  = "ops\backlog.json",
  [string]$CrudId   = "equipment_ui"
)
$ErrorActionPreference = "Stop"

function Replace-First {
  param([string]$text,[string]$pattern,[string]$replacement)
  $rx = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  return $rx.Replace($text, $replacement, 1)
}

if (-not (Test-Path $Backlog)) { throw ("Backlog not found: {0}" -f $Backlog) }
$plan = Get-Content $Backlog -Raw | ConvertFrom-Json
$eqp  = $plan | Where-Object { $_.id -eq $CrudId } | Select-Object -First 1
if (-not $eqp) { throw ("Crud id not found in backlog: {0}" -f $CrudId) }

$searchQ = $eqp.data.search_q
if (-not $searchQ -or $searchQ -eq "") { $searchQ = $eqp.data.name }

$addUrl  = $eqp.urls.add
$listUrl = $eqp.urls.list_direct
$listSel = if ($eqp.selectors.list_table) { $eqp.selectors.list_table } else { "table#result_list" }
$formSel = if ($eqp.selectors.form) { $eqp.selectors.form } else { "form" }

# row link hedefi: varsa ?ablon, yoksa has-text(searchQ)
$rowSel = $null
if ($eqp.selectors.row_link) {
  $rowSel = $eqp.selectors.row_link -replace "\{\{search_q\}\}", [regex]::Escape($searchQ)
}
if (-not $rowSel -or $rowSel -eq "") {
  $rowSel = 'table#result_list tbody tr:has-text("' + $searchQ + '") th > a'
}

# hedef dosyalar
$targetFiles = @(
  (Join-Path $FlowsDir "__make_baseline_admin_equipment_change.flow"),
  (Join-Path $FlowsDir "equipment_ui_change.flow"),
  (Join-Path $FlowsDir "equipment_ui_delete.flow"),
  (Join-Path $FlowsDir "equipment_ui_list.flow")
) | Where-Object { Test-Path $_ }

foreach ($f in $targetFiles) {
  $txt = Get-Content $f -Raw

  # 1) Listeye git + liste selector'?n? bekle
  $patternWait = '^(WAIT\s+SELECTOR\s+)[^\r\n]+'
  $replaceWait = 'GOTO  ' + $listUrl + "`r`n" + 'WAIT  SELECTOR ' + $listSel
  $txt = Replace-First $txt $patternWait $replaceWait

  # 2) Sat?r se?im stratejisi
  $patFirst = 'CLICK\s+table#result_list\s+tbody\s+tr:first-child\s+th\s*>\s*a'
  $txt = [regex]::Replace($txt, $patFirst, ('CLICK  ' + $rowSel))

  Set-Content -Path $f -Value $txt -Encoding ASCII
  Write-Host ("[ok] patched: {0}" -f $f) -ForegroundColor Green
}

# CREATE flow'u: add URL + form bekleme
$createFlow = Join-Path $FlowsDir "equipment_ui_create.flow"
if (Test-Path $createFlow) {
  $txt = Get-Content $createFlow -Raw
  $inject = 'GOTO  ' + $addUrl + "`r`n" + 'WAIT  SELECTOR ' + $formSel + "`r`n"
  if ($txt -match '(?m)^[ ]*FILL\s+') {
    $txt = Replace-First $txt '^(?=FILL\s+)' $inject
  } else {
    $txt = $inject + $txt
  }
  Set-Content -Path $createFlow -Value $txt -Encoding ASCII
  Write-Host ("[ok] patched: {0}" -f $createFlow) -ForegroundColor Green
}
