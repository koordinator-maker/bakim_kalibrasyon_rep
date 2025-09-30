param(
  [string]$FlowsDir = "ops\flows"
)
$ErrorActionPreference = "Stop"

$create   = Join-Path $FlowsDir "equipment_ui_create.flow"
$validate = Join-Path $FlowsDir "equipment_ui_create_validate.flow"
if (-not (Test-Path $create))   { throw "Flow yok: $create" }
if (-not (Test-Path $validate)) { throw "Flow yok: $validate" }

# 1) create.flow i?inden arama metnini ??kar (?nce code, yoksa name)
$c = Get-Content -LiteralPath $create -Raw
$searchQ = $null

# ?e?itli FILL desenlerini yakala (t?rnakl? / t?rnaks?z)
$rxs = @(
  '(?m)^\s*FILL\s+.*?(id_code|name=code)[^\r\n]*\s+"([^"]+)"\s*$',
  '(?m)^\s*FILL\s+.*?(id_code|name=code)[^\r\n]*\s+([^\r\n"]+)\s*$',
  '(?m)^\s*FILL\s+.*?(id_name|name=name)[^\r\n]*\s+"([^"]+)"\s*$',
  '(?m)^\s*FILL\s+.*?(id_name|name=name)[^\r\n]*\s+([^\r\n"]+)\s*$'
)
foreach ($p in $rxs) {
  $m = [regex]::Match($c, $p)
  if ($m.Success) { $searchQ = $m.Groups[$m.Groups.Count-1].Value.Trim(); break }
}
if (-not $searchQ -or $searchQ -eq "") { $searchQ = "EQP" }

# 2) validate flow?u BA?TAN yaz:
# login -> (next=/_direct/) -> tabloyu bekle -> sat?r? metne g?re bekle
$lines = @()
$lines += 'GOTO  /admin/login/?next=/admin/maintenance/equipment/_direct/'
$lines += 'WAIT  SELECTOR input[name=username]'
$lines += 'FILL  input[name=username]  admin'
$lines += 'FILL  input[name=password]  Admin!2345'
$lines += 'CLICK input[type=submit]'
$lines += 'WAIT  SELECTOR table#result_list'
$lines += ('WAIT  SELECTOR table#result_list tbody tr:has-text("'+$searchQ+'")')

Set-Content -LiteralPath $validate -Value ($lines -join "`r`n") -Encoding ASCII
Write-Host ("[ok] rewrote: {0} (search_q='{1}')" -f $validate, $searchQ) -ForegroundColor Green
