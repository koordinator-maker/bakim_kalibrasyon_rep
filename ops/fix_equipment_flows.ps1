# Rev: 2025-10-01 minimal fix (no backlog dependency) ? r3
param(
  [string]$FlowsDir = "ops\flows"
)
$ErrorActionPreference = "Stop"

function Ensure-Login {
  param([string]$txt)
  if ($txt -match '/logout/') { return $txt }
  $lines = @()
  $lines += 'GOTO  /admin/login/'
  $lines += 'WAIT  SELECTOR input[name=username]'
  $lines += 'FILL  input[name=username]  admin'
  $lines += 'FILL  input[name=password]  Admin!2345'
  $lines += 'CLICK input[type=submit]'
  # burada logout beklemiyoruz; hedef sayfada bekleyece?iz
  return ($lines -join "`r`n") + "`r`n" + $txt
}

function Replace-SelectorOr {
  param([string]$txt,[string]$fallback)
  return [regex]::Replace($txt,'(?m)^WAIT\s+SELECTOR-OR[^\r\n]+','WAIT  SELECTOR ' + $fallback)
}

function Prepend-Once {
  param([string]$txt,[string]$needle,[string]$block)
  if ($txt -like ('*' + $needle + '*')) { return $txt }
  return $block + "`r`n" + $txt
}

if (-not (Test-Path $FlowsDir)) { throw ("Flows dir not found: {0}" -f $FlowsDir) }

$targets = Get-ChildItem -Path $FlowsDir -Filter "*equipment*.flow" -File | Sort-Object Name
if (-not $targets) { Write-Host "[warn] no *equipment*.flow found" -ForegroundColor Yellow; exit 0 }

foreach ($f in $targets) {
  $full = $f.FullName
  $txt  = Get-Content -LiteralPath $full -Raw

  # 1) login blo?u (logout beklemek yok)
  $txt = Ensure-Login $txt

  # 2) desteklenmeyen SELECTOR-OR varsa sadele?tir
  $txt = Replace-SelectorOr $txt "#content-main"

  $name = $f.Name.ToLower()

  if ($name -like "*create.flow") {
    # 3a) CREATE: add URL + form bekle
    $inj  = "GOTO  /admin/maintenance/equipment/add/`r`n"
    $inj += "WAIT  SELECTOR form`r`n"
    $txt = Prepend-Once $txt "/admin/maintenance/equipment/add/" $inj
  } else {
    # 3b) CHANGE/DELETE/LIST: _direct liste + tablo bekle
    $inj  = "GOTO  /admin/maintenance/equipment/_direct/`r`n"
    $inj += "WAIT  SELECTOR table#result_list`r`n"
    $txt = Prepend-Once $txt "/admin/maintenance/equipment/_direct/" $inj
  }

  Set-Content -LiteralPath $full -Value $txt -Encoding ASCII
  Write-Host ("[ok] patched: {0}" -f $f.Name) -ForegroundColor Green
}
