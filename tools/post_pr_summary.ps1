# tools/post_pr_summary.ps1
# Rev: r4 (gh opsiyonel; Windows PowerShell/pwsh uyumlu)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$report = "_otokodlama/out/pw.json"
if (-not (Test-Path $report)) {
  Write-Host "No json report at $report"
  exit 0
}

# ---- parse playwright json ----
$json = Get-Content $report -Raw | ConvertFrom-Json
$stats = [ordered]@{ total=0; passed=0; failed=0; skipped=0; durationMs=0 }

function Add-Spec {
  param($spec)
  if ($null -eq $spec) { return }
  $stats.total++
  # outcomes
  $outcomes = @()
  if ($spec.tests -and $spec.tests[0] -and $spec.tests[0].results) {
    $outcomes = $spec.tests[0].results.outcome
    $dur = ($spec.tests[0].results | Measure-Object duration -Sum).Sum
    if ($dur) { $stats.durationMs += [double]$dur }
  }
  if ($spec.ok) { $stats.passed++ }
  elseif ($outcomes -contains "skipped") { $stats.skipped++ }
  else { $stats.failed++ }
}

foreach ($proj in $json.suites) {
  foreach ($suite in $proj.suites) {
    foreach ($spec in $suite.specs) { Add-Spec $spec }
  }
}

$mins  = [Math]::Round(($stats.durationMs/60000), 2)
$badge = if ($stats.failed -gt 0) { "🔴" } else { "🟢" }

$body = @"
## $badge E2E Sonuç Özeti
- Toplam: **$($stats.total)** | Geçti: **$($stats.passed)** | Kaldı: **$($stats.failed)** | Skip: **$($stats.skipped)**
- Süre (yaklaşık): **$mins dk**

> HTML rapor: Actions → Artifacts → **playwright-report**
"@

$inCI = [bool]$env:GITHUB_ACTIONS
$prNumber = $env:PR_NUMBER

# gh opsiyonel
$ghExists = $false
try { $null = Get-Command gh -ErrorAction Stop; $ghExists = $true } catch {}

if ($inCI -and $prNumber -and $ghExists) {
  $repo = $env:GITHUB_REPOSITORY
  $null = & gh api "repos/$repo/issues/$prNumber/comments" -f body="$body"
  Write-Host "Posted PR comment to #$prNumber"
} else {
  Write-Host $body
  [IO.File]::WriteAllText("_otokodlama/out/last_pr_summary.md", $body, [Text.UTF8Encoding]::new($false))
  Write-Host "Saved to _otokodlama/out/last_pr_summary.md"
}