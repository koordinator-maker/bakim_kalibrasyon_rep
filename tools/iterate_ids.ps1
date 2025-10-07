param(
  [string[]] $Ids = @('E105','E106','E107','E108','E109','E110'),
  [int]      $MaxTries = 15
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if (-not $env:BASE_URL)   { $env:BASE_URL   = "http://127.0.0.1:8010" }
if (-not $env:ADMIN_USER) { $env:ADMIN_USER = "admin" }
if (-not $env:ADMIN_PASS) { $env:ADMIN_PASS = "admin123!" }

$Map = @{
  E105 = 'tests/e105_list_search_exact.spec.js'
  E106 = 'tests/e106_list_search_partial.spec.js'
  E107 = 'tests/e107_edit_equipment.spec.js'
  E108 = 'tests/e108_required_validation.spec.js'
  E109 = 'tests/e109_search_result_presence.spec.js'
  E110 = 'tests/e110_permission_redirect.spec.js'
}

function Run-One([string]$id, [int]$max) {
  if (-not $Map.ContainsKey($id)) { Write-Host "[$id] için dosya yok." -ForegroundColor Red; return $false }
  $file = $Map[$id]
  Write-Host "`n=== $id için yineleme başlıyor (max $max) ===" -ForegroundColor Cyan
  for ($i=1; $i -le $max; $i++) {
    Write-Host "[$id] Deneme $i..." -ForegroundColor Yellow

    npx playwright test $file --project=chromium --reporter=line,html,blob
    $ok = ($LASTEXITCODE -eq 0)

    New-Item -ItemType Directory -Force _otokodlama\out | Out-Null
    npx playwright merge-reports --reporter=json blob-report > _otokodlama/out/pw.json
    powershell -ExecutionPolicy Bypass -File tools/post_pr_summary.ps1

    if ($ok) { Write-Host "[$id] BAŞARILI ✅" -ForegroundColor Green; return $true }
    Write-Host "[$id] Başarısız, tekrar denenecek..." -ForegroundColor Red
  }
  Write-Host "[$id] Maksimum denemeye ulaşıldı ❌" -ForegroundColor Red
  return $false
}

$allOk = $true
foreach ($id in $Ids) { if (-not (Run-One $id $MaxTries)) { $allOk = $false } }
if ($allOk) { Write-Host "`nTÜM ID'ler başarıyla geçti. 🎉" -ForegroundColor Green } else { exit 1 }