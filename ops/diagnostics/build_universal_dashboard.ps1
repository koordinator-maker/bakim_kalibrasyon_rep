param(
  [string]$Repo = ".",
  [string]$ReportsDir = "_otokodlama\reports"
)

chcp 65001 > $null
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding            = [Text.UTF8Encoding]::new($false)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = Resolve-Path $Repo
Set-Location $repo

$reportsRoot = Join-Path $repo $ReportsDir
if (-not (Test-Path $reportsRoot)) { New-Item -ItemType Directory -Force -Path $reportsRoot | Out-Null }

$dashboardDir = Join-Path $reportsRoot "dashboard"
New-Item -ItemType Directory -Force -Path $dashboardDir | Out-Null

$txtReports = Get-ChildItem $reportsRoot -File -Filter "universal_findings_*.txt" | Sort-Object LastWriteTime
if (-not $txtReports) { Write-Host "Rapor bulunamadı"; exit 0 }

$timelineCsv = Join-Path $dashboardDir "universal_timeline.csv"
$timelineMd  = Join-Path $dashboardDir "universal_timeline.md"

$rows = New-Object System.Collections.Generic.List[object]
foreach ($f in $txtReports) {
  $raw  = Get-Content $f.FullName -Raw
  $pass = ([regex]::Matches($raw, '\[PASS\]')).Count
  $warn = ([regex]::Matches($raw, '\[WARN\]')).Count
  $fail = ([regex]::Matches($raw, '\[FAIL\]')).Count
  $name  = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $stamp = $name -replace '^universal_findings_', ''
  $rows.Add([pscustomobject]@{ Timestamp=$stamp; File=$f.Name; PASS=$pass; WARN=$warn; FAIL=$fail })
}
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $timelineCsv

$md = New-Object System.Text.StringBuilder
$null = $md.AppendLine('# Universal Findings — Timeline')
$null = $md.AppendLine('')
$null = $md.AppendLine('| Timestamp | PASS | WARN | FAIL | File |')
$null = $md.AppendLine('|---|---:|---:|---:|---|')
foreach ($r in $rows) {
  $null = $md.AppendLine( ('| {0} | {1} | {2} | {3} | {4} |' -f $r.Timestamp,$r.PASS,$r.WARN,$r.FAIL,$r.File) )
}
[IO.File]::WriteAllText($timelineMd, $md.ToString(), [Text.UTF8Encoding]::new($false))

$latest     = $txtReports[-1]
$latestRaw  = Get-Content $latest.FullName -Raw
$lines      = $latestRaw -split '`r?`n'

$secName = 'HEADER'
$details = New-Object System.Collections.Generic.List[object]
foreach ($ln in $lines) {
  if ($ln -match '^\s*===\s*(.+?)\s*===\s*$') { $secName = $Matches[1]; continue }
  if ($ln -match '^\[(PASS|WARN|FAIL)\]\s+(.*)$') {
    $status = $Matches[1]; $msg = $Matches[2]
    if ($status -ne 'PASS') { $details.Add([pscustomobject]@{ Section=$secName; Status=$status; Message=$msg }) }
  }
}

$latestStamp = ([IO.Path]::GetFileNameWithoutExtension($latest.Name)) -replace '^universal_findings_', ''
$detailsCsv  = Join-Path $dashboardDir ("details_" + $latestStamp + ".csv")
$totalsCsv   = Join-Path $dashboardDir ("totals_"  + $latestStamp + ".csv")

if ($details.Count -gt 0) { $details | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $detailsCsv }
else { 'Section,Status,Message' | Out-File -FilePath $detailsCsv -Encoding UTF8 }

$passL = ([regex]::Matches($latestRaw, '\[PASS\]')).Count
$warnL = ([regex]::Matches($latestRaw, '\[WARN\]')).Count
$failL = ([regex]::Matches($latestRaw, '\[FAIL\]')).Count
$tot = [pscustomobject]@{ Timestamp=$latestStamp; PASS=$passL; WARN=$warnL; FAIL=$failL; File=$latest.Name }
$tot | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $totalsCsv

$indexMd = Join-Path $dashboardDir "index.md"
$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine('# Universal Dashboard')
$null = $sb.AppendLine('')
$null = $sb.AppendLine( ('**Timeline CSV:** `{0}`'       -f (Split-Path -Leaf $timelineCsv)) )
$null = $sb.AppendLine( ('**Timeline MD :** `{0}`'       -f (Split-Path -Leaf $timelineMd)) )
$null = $sb.AppendLine('')
$null = $sb.AppendLine( ('**Latest details CSV:** `{0}`' -f (Split-Path -Leaf $detailsCsv)) )
$null = $sb.AppendLine( ('**Latest totals  CSV:** `{0}`' -f (Split-Path -Leaf $totalsCsv)) )
$null = $sb.AppendLine('')
$null = $sb.AppendLine('> Bu pano yalnız **tespit/bildirim** amaçlıdır. Yeni test oluşturmaz.')
[IO.File]::WriteAllText($indexMd, $sb.ToString(), [Text.UTF8Encoding]::new($false))

Write-Host ("[DASHBOARD] Timeline CSV    : " + $timelineCsv)
Write-Host ("[DASHBOARD] Timeline MD     : " + $timelineMd)
Write-Host ("[DASHBOARD] Latest details  : " + $detailsCsv)
Write-Host ("[DASHBOARD] Latest totals   : " + $totalsCsv)
Write-Host ("[DASHBOARD] Index           : " + $indexMd)
