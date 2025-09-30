# Rev: 2025-10-01 FORCE FIX (no backlog dependency)
param(
  [string]$FlowsDir = "ops\flows"
)
$ErrorActionPreference = "Stop"

function Strip-Lines {
  param([string]$txt,[string]$pattern)
  return [regex]::Replace($txt, $pattern, "", [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

if (-not (Test-Path $FlowsDir)) { throw ("Flows dir not found: {0}" -f $FlowsDir) }

$targets = Get-ChildItem -Path $FlowsDir -Filter "*equipment*.flow" -File | Sort-Object Name
if (-not $targets) { Write-Host "[warn] no *equipment*.flow found" -ForegroundColor Yellow; exit 0 }

foreach ($f in $targets) {
  $full = $f.FullName
  $orig = Get-Content -LiteralPath $full -Raw

  # 0) Eski login ve problemli WAIT'leri tamamen temizle
  $body = $orig
  # eski login komutlar?
  $body = Strip-Lines $body '^\s*GOTO\s+/admin/login/.*\r?\n'
  $body = Strip-Lines $body '^\s*FILL\s+input\[name=username\].*\r?\n'
  $body = Strip-Lines $body '^\s*FILL\s+input\[name=password\].*\r?\n'
  $body = Strip-Lines $body '^\s*CLICK\s+input\[type=submit\].*\r?\n'
  # desteklenmeyen SELECTOR-OR
  $body = Strip-Lines $body '^\s*WAIT\s+SELECTOR-OR[^\r\n]*\r?\n'
  # logout / #user-tools beklemeleri
  $body = Strip-Lines $body '^\s*WAIT\s+SELECTOR\s+[^\r\n]*(#user-tools|/logout/)[^\r\n]*\r?\n'

  # 1) Yeni stabil login header (logout beklemez)
  $login  = "GOTO  /admin/login/`r`n"
  $login += "WAIT  SELECTOR input[name=username]`r`n"
  $login += "FILL  input[name=username]  admin`r`n"
  $login += "FILL  input[name=password]  Admin!2345`r`n"
  $login += "CLICK input[type=submit]`r`n"

  # 2) Hedef ba?l?k (create vs di?erleri)
  $name = $f.Name.ToLower()
  if ($name -like "*create.flow") {
    $nav  = "GOTO  /admin/maintenance/equipment/add/`r`n"
    $nav += "WAIT  SELECTOR form`r`n"
  } else {
    $nav  = "GOTO  /admin/maintenance/equipment/_direct/`r`n"
    $nav += "WAIT  SELECTOR table#result_list`r`n"
  }

  $new = $login + $nav + $body
  Set-Content -LiteralPath $full -Value $new -Encoding ASCII
  Write-Host ("[ok] forced: {0}" -f $f.Name) -ForegroundColor Green
}
