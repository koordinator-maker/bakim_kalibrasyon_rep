param(
  [string]$Repo       = ".",
  [string]$ReportsDir = "_otokodlama\reports",
  [string]$BundleDir  = "_otokodlama\bundle"
)
chcp 65001 > $null
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding            = [Text.UTF8Encoding]::new($false)
Set-StrictMode -Version Latest; $ErrorActionPreference = "Stop"
$repo        = Resolve-Path $Repo
$reportsRoot = Join-Path $repo $ReportsDir
$dash        = Join-Path $reportsRoot "dashboard"
$junitDir    = Join-Path $reportsRoot "junit"
$bundleRoot  = Join-Path $repo $BundleDir
if (-not (Test-Path $dash)) { New-Item -ItemType Directory -Force -Path $dash | Out-Null }
function Get-LatestFile([string]$dir, [string]$filter){
  if (-not (Test-Path $dir)) { return $null }
  Get-ChildItem $dir -File -Filter $filter | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
# PowerShell 5.1 uyumlu göreli yol
function Get-RelativePath {
  param([Parameter(Mandatory)][string]$FromDir, [Parameter(Mandatory)][string]$ToPath)
  try {
    $fromPath = (Resolve-Path $FromDir).Path
    if (-not (Test-Path $fromPath -PathType Container)) { $fromPath = Split-Path -Parent $fromPath }
    if ($fromPath[-1] -ne [IO.Path]::DirectorySeparatorChar) { $fromPath += [IO.Path]::DirectorySeparatorChar }
    $toPath   = (Resolve-Path $ToPath).Path
    $fromUri = [Uri]("file:///" + $fromPath.Replace('\','/'))
    $toUri   = [Uri]("file:///" + $toPath.Replace('\','/'))
    $rel = $fromUri.MakeRelativeUri($toUri).OriginalString
    return ($rel -replace '/', '\')
  } catch {
    return $ToPath
  }
}
$latestDetails = Get-LatestFile $dash      'details_*.csv'
$latestTotals  = Get-LatestFile $dash      'totals_*.csv'
$latestJUnit   = Get-LatestFile $junitDir  'universal_junit_*.xml'
$latestBundle  = Get-LatestFile $bundleRoot 'bundle_*.zip'
# Playwright report (varsa)
$pwReport = Join-Path $repo "playwright-report\index.html"
if (-not (Test-Path $pwReport)) { $pwReport = $null }
# Totals özeti
$summary = ""
if ($latestTotals) {
  try {
    $t = Import-Csv $latestTotals.FullName | Select-Object -First 1
    $summary = "PASS=$($t.PASS) • WARN=$($t.WARN) • FAIL=$($t.FAIL)"
  } catch { $summary = "" }
}
$htmlPath = Join-Path $dash "quicklinks.html"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<!doctype html><meta charset="utf-8">')
[void]$sb.AppendLine('<title>Universal Quick Links</title>')
[void]$sb.AppendLine('<style>body{font:14px system-ui,Segoe UI,Roboto,Arial} a{color:#0a58ca;text-decoration:none} .box{margin:12px 0;padding:12px;border:1px solid #ddd;border-radius:10px} h1{font-size:18px;margin:0 0 6px}</style>')
[void]$sb.AppendLine('<h1>Universal Quick Links</h1>')
if ($summary) { [void]$sb.AppendLine("<div class='box'><b>Summary:</b> $summary</div>") }
[void]$sb.AppendLine('<div class="box"><b>Latest files</b><ul>')
if ($latestDetails) {
  $rel = Get-RelativePath -FromDir $dash -ToPath $latestDetails.FullName
  [void]$sb.AppendLine("<li>Details CSV: <a href='$rel'>$($latestDetails.Name)</a></li>")
} else { [void]$sb.AppendLine("<li>Details CSV: (yok)</li>") }
if ($latestTotals) {
  $rel = Get-RelativePath -FromDir $dash -ToPath $latestTotals.FullName
  [void]$sb.AppendLine("<li>Totals CSV: <a href='$rel'>$($latestTotals.Name)</a></li>")
} else { [void]$sb.AppendLine("<li>Totals CSV: (yok)</li>") }
if ($latestJUnit) {
  $rel = Get-RelativePath -FromDir $dash -ToPath $latestJUnit.FullName
  [void]$sb.AppendLine("<li>JUnit XML: <a href='$rel'>$($latestJUnit.Name)</a></li>")
} else { [void]$sb.AppendLine("<li>JUnit XML: (yok)</li>") }
if ($latestBundle) {
  $rel = Get-RelativePath -FromDir $dash -ToPath $latestBundle.FullName
  [void]$sb.AppendLine("<li>Bundle ZIP: <a href='$rel'>$($latestBundle.Name)</a></li>")
} else { [void]$sb.AppendLine("<li>Bundle ZIP: (yok)</li>") }
if ($pwReport) {
  $rel = Get-RelativePath -FromDir $dash -ToPath $pwReport
  [void]$sb.AppendLine("<li>Playwright Report: <a href='$rel'>index.html</a></li>")
} else { [void]$sb.AppendLine("<li>Playwright Report: (yok)</li>") }
[void]$sb.AppendLine('</ul></div>')
[IO.File]::WriteAllText($htmlPath, $sb.ToString(), [Text.UTF8Encoding]::new($false))
Write-Host "[QUICKLINKS] $htmlPath"