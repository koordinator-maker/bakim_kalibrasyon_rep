Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)

# repo kökü ve rapor
$repo = (& git rev-parse --show-toplevel) 2>$null; if(-not $repo){ $repo=(Get-Location).Path }
$pw   = Join-Path $repo '_otokodlama\out\pw.json'
if(!(Test-Path $pw)){ Write-Host "No pw.json at $pw"; exit 0 }

# json’u yükle
$json = Get-Content $pw -Raw -Encoding UTF8 | ConvertFrom-Json

# istatistik topla (blob-json şeması)
$total=0;$passed=0;$failed=0;$skipped=0;$flaky=0;$durationMs=0
foreach($proj in $json.suites){
  foreach($suite in $proj.suites){
    foreach($spec in $suite.specs){
      $total++
      $ok = $false
      if($spec | Get-Member -Name ok -MemberType NoteProperty){ $ok = [bool]$spec.ok }
      $res = @()
      if($spec.tests -and $spec.tests[0] -and $spec.tests[0].results){ $res = $spec.tests[0].results }
      $durationMs += [double](($res | Measure-Object duration -Sum).Sum)
      if($ok){ $passed++ }
      elseif($res.outcome -contains 'skipped'){ $skipped++ }
      else { $failed++ }
    }
  }
}

$mins = if($durationMs){ [Math]::Round($durationMs/60000,2) } else { 0 }
$badge = if($failed -gt 0){ "🔴" } else { "🟢" }

$body = @"
## $badge E2E Sonuç Özeti
- Toplam: **$total** | Geçti: **$passed** | Kaldı: **$failed** | Skip: **$skipped** | Flaky: **$flaky**
- Süre (yaklaşık): **$mins dk**

> HTML rapor: Actions → Artifacts → **playwright-report**
"@

Write-Host $body
$outDir = Join-Path $repo '_otokodlama\out'
New-Item -ItemType Directory -Force $outDir | Out-Null
[IO.File]::WriteAllText((Join-Path $outDir 'last_pr_summary.md'), $body, [Text.UTF8Encoding]::new($false))