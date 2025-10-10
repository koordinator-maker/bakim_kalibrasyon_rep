# tools/accept_visual.ps1
# Görsel kabul (baseline güncelleme) otomasyonu
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path

# 1) config oku
$cfgPath = Join-Path $RepoRoot "pipeline.config.json"
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$mode = $cfg.acceptance.mode
$auto = $cfg.acceptance.auto_accept_if

# 2) layout_report.json nerede? (root veya _otokodlama/out altında)
$report = $null
$try1 = Join-Path $RepoRoot "layout_report.json"
if (Test-Path $try1) { $report = $try1 } else {
  $outDir = Join-Path $RepoRoot "_otokodlama\out"
  if (Test-Path $outDir) {
    $last = Get-ChildItem $outDir -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($last) {
      $try2 = Join-Path $last.FullName "layout_report.json"
      if (Test-Path $try2) { $report = $try2 }
    }
  }
}
if (-not $report) { Write-Host "[ACCEPT] layout_report.json bulunamadı." ; exit 0 }

$j = Get-Content $report -Raw | ConvertFrom-Json
$sim = [double]$j.similarity
$latest = Resolve-Path (Join-Path $RepoRoot $j.latest_screenshot)
$target = Resolve-Path (Join-Path $RepoRoot $j.target)

Write-Host "[ACCEPT] mode=$mode similarity=$sim target=$(Split-Path $target -Leaf)"

function Accept-Baseline {
  Copy-Item $latest $target -Force
  Write-Host "[ACCEPT] Baseline güncellendi -> $($target)"
}

switch ($mode) {
  "locked"  { Write-Host "[ACCEPT] locked modunda otomatik kabul yapılmaz." ; exit 0 }
  "rolling" { Accept-Baseline ; exit 0 }
  "guided"  {
    if ($sim -ge $auto) { Accept-Baseline ; exit 0 }
    else { Write-Host "[ACCEPT] guided: otomatik kabul eşiği tutmadı (>= $auto gerekli)." ; exit 0 }
  }
  default   { Write-Host "[ACCEPT] Bilinmeyen mode: $mode" ; exit 0 }
}
