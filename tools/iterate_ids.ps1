\
param(
  [int]$Cycles,
  [string]$Project,
  [switch]$Headed,
  [switch]$Debug
)

Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'; trap { throw }
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if (-not $PSBoundParameters.ContainsKey('Cycles'))  { $Cycles  = 15 }
if (-not $PSBoundParameters.ContainsKey('Project')) { $Project = 'chromium' }

if (-not $env:BASE_URL) { $env:BASE_URL = "http://127.0.0.1:8010" }
$env:PLAYWRIGHT_BEEP = "1"
if ($Debug) { $env:PWDEBUG = "1" }

$headedArg = $null
if ($Headed) { $headedArg = "--headed" }

$npx = Join-Path $env:ProgramFiles "nodejs\npx.cmd"
if (!(Test-Path $npx)) { $npx = "npx" }

$tests = @(
  "tests/helpers_e10x.js",
  "tests/e106_list_filter.spec.js",
  "tests/e107_edit_equipment.spec.js",
  "tests/e108_validation.spec.js",
  "tests/e109_permission_anonymous.spec.js",
  "tests/e110_bulk_filter_reset.spec.js"
)

for ($i = 1; $i -le $Cycles; $i++) {
  $env:TEST_CYCLE = "$i"
  Write-Host ""
  Write-Host ("==== CYCLE {0}/{1} ====" -f $i, $Cycles) -ForegroundColor Cyan

  foreach ($t in $tests) {
    if (-not (Test-Path $t)) { Write-Host "[SKIP] $t (yok)" -ForegroundColor Yellow; continue }
    if ($t -like "*helpers_e10x.js") { continue } # not a test
    $args = @('playwright','test', $t, "--project=$Project")
    if ($headedArg) { $args += $headedArg }
    & $npx @args
    if ($LASTEXITCODE -ne 0) {
      Write-Host "[FAIL] $t (cycle $i)" -ForegroundColor Red
    } else {
      Write-Host "[PASS] $t (cycle $i)" -ForegroundColor Green
    }
  }
}

Write-Host "`n[iterate_ids.ps1] tamamlandı." -ForegroundColor Green
