# tools/post_pr_summary.ps1
# Rev: r6 — missing stats guard
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$report = "test-results/.last-run.json"
if (-not (Test-Path $report)) {
  Write-Host "No summary at $report"
  exit 0
}

$json = Get-Content $report -Raw | ConvertFrom-Json

# ---- Guard: stats yoksa nazikçe çık ----
if (-not ($json.PSObject.Properties.Name -contains 'stats')) {
  Write-Host "Summary has no 'stats' (run probably failed before reporting)."
  [IO.File]::WriteAllText("_otokodlama/out/last_pr_summary.md",
    "## 🔴 E2E Sonuç Özeti`n- Rapor oluşamadı (global setup veya erken hata).`n> HTML rapor yoksa test koştuktan sonra tekrar deneyin.",
    [Text.UTF8Encoding]::new($false))
  exit 0
}

$expected   = [int]$json.stats.expected
$skipped    = [int]$json.stats.skipped
$unexpected = [int]$json.stats.unexpected
$flaky      = [int]$json.stats.flaky
$durationMs = [double]$json.stats.duration
$total      = $expected + $skipped + $unexpected + $flaky
$passed     = $expected
$failed     = $unexpected

$mins  = [Math]::Round(($durationMs/60000), 2)
$badge = if ($failed -gt 0) { "🔴" } else { "🟢" }

$body = @"
## $badge E2E Sonuç Özeti
- Toplam: **$total** | Geçti: **$passed** | Kaldı: **$failed** | Skip: **$skipped** | Flaky: **$flaky**
- Süre (yaklaşık): **$mins dk**

> HTML rapor: Actions → Artifacts → **playwright-report**
"@

$inCI = [bool]$env:GITHUB_ACTIONS
$prNumber = $env:PR_NUMBER

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