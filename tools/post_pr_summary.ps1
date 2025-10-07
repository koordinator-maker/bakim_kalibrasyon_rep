Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# Kaynak (blob-merge JSON)
$repo = (& git rev-parse --show-toplevel) 2>$null; if (-not $repo) { $repo = (Get-Location).Path }
$pw   = Join-Path $repo '_otokodlama\out\pw.json'
if (!(Test-Path $pw)) { Write-Host "No pw.json at $pw (önce blob+merge-reports üret)."; exit 0 }

$json = Get-Content $pw -Raw -Encoding UTF8 | ConvertFrom-Json

# Sayaçlar
$total=0; $passed=0; $failed=0; $skipped=0; $flaky=0; $durationMs=0

function Add-ByResults {
  param($ok,$results)
  $script:total++
  if ($results) {
    $sum = ($results | Measure-Object duration -Sum).Sum
    if ($sum) { $script:durationMs += [double]$sum }
  }
  if ($ok -is [bool]) {
    if ($ok) { $script:passed++ }
    else {
      if ($results -and (($results.outcome -contains 'skipped') -or ($results.status -contains 'skipped'))) {
        $script:skipped++
      } else { $script:failed++ }
    }
    return
  }
  if ($results) {
    $st = @($results.status) + @($results.outcome)
    if     ($st -match 'skip')                     { $script:skipped++ }
    elseif ($st -match 'pass|ok|success|expected') { $script:passed++ }
    elseif ($st -match 'flaky')                    { $script:flaky++ }
    else                                           { $script:failed++ }
  } else { $script:failed++ }
}

function Walk($node) {
  if ($null -eq $node) { return }
  if ($node -is [System.Array]) { foreach ($n in $node) { Walk $n } ; return }
  if ($node -isnot [psobject])  { return }
  $props = $node.PSObject.Properties.Name

  # .last-run.json şeması çıkarsa direkt kullan
  if ($props -contains 'stats' -and $node.stats) {
    $script:passed     = [int]$node.stats.expected
    $script:skipped    = [int]$node.stats.skipped
    $script:failed     = [int]$node.stats.unexpected
    if ($node.stats.PSObject.Properties.Name -contains 'flaky') { $script:flaky = [int]$node.stats.flaky }
    $script:durationMs = [double]$node.stats.duration
    $script:total      = $script:passed + $script:skipped + $script:failed + $script:flaky
    return
  }

  # Playwright JSON ağaçları (blob/html)
  if ($props -contains 'specs' -and $node.specs) {
    foreach ($spec in $node.specs) {
      $ok = $false; if ($spec | Get-Member -Name ok -MemberType NoteProperty) { $ok = [bool]$spec.ok }
      $results = @()
      if ($spec.tests -and $spec.tests[0] -and $spec.tests[0].results) { $results = $spec.tests[0].results }
      Add-ByResults -ok:$ok -results:$results
    }
  }

  if ($props -contains 'suites'        -and $node.suites)        { Walk $node.suites }
  if ($props -contains 'projectSuites' -and $node.projectSuites) { Walk $node.projectSuites }
  if ($props -contains 'report'        -and $node.report)        { Walk $node.report }

  foreach ($p in $props) {
    $v = $node.$p
    if ($v -is [System.Array] -or $v -is [psobject]) { Walk $v }
  }
}

Walk $json

# Çıktı (ASCII rozet)
$mins  = if ($durationMs -gt 0) { [Math]::Round(($durationMs/60000), 2) } else { 0 }
$badge = if ($failed -gt 0) { "[FAIL]" } else { "[PASS]" }

$body = @"
## $badge E2E Sonuç Özeti
- Toplam: **$total** | Geçti: **$passed** | Kaldı: **$failed** | Skip: **$skipped** | Flaky: **$flaky**
- Süre (yaklaşık): **$mins dk**

> HTML rapor: Actions -> Artifacts -> playwright-report
"@

Write-Host $body
$outDir = Join-Path $repo '_otokodlama\out'
New-Item -ItemType Directory -Force $outDir | Out-Null
[IO.File]::WriteAllText((Join-Path $outDir 'last_pr_summary.md'), $body, [Text.UTF8Encoding]::new($false))