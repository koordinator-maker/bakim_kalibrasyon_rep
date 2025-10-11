param(
  [string]$Repo = ".",
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [string]$EntryPath = "/admin/",
  [string]$ReportsDir = "_otokodlama\reports",
  [string]$BundleDir  = "_otokodlama\bundle",
  [switch]$Zip = $true,
  [switch]$GateOnFail = $true,
  [switch]$WarnAsSkip = $true
)
chcp 65001 > $null
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding            = [Text.UTF8Encoding]::new($false)
Set-StrictMode -Version Latest; $ErrorActionPreference="Stop"
$repo = Resolve-Path $Repo; Set-Location $repo
$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
$reportsRoot = Join-Path $repo $ReportsDir
$bundleRoot  = Join-Path $repo $BundleDir
$diagDir     = Join-Path $repo "ops\diagnostics"
$null = New-Item -ItemType Directory -Force -Path $reportsRoot,$bundleRoot,$diagDir | Out-Null
# 1) Rapor (TXT üretir)
& (Join-Path $diagDir "report_universal.ps1") -Repo $repo -OutDir $ReportsDir -BaseUrl $BaseUrl -EntryPath $EntryPath
# 2) Dashboard (timeline, totals, index) - BU ADIM ARTIK ÖNCE
& (Join-Path $diagDir "build_universal_dashboard.ps1") -Repo $repo -ReportsDir $ReportsDir
# 3) TXT -> details CSV (bizim sağlam çıkarım) - EN SON YAZSIN
& (Join-Path $diagDir "extract_from_txt.ps1") -Repo $repo -ReportsDir $ReportsDir
# 3b) Sigorta: header-only kaldıysa tekrar düzelt
$dashDir = Join-Path $reportsRoot "dashboard"
$lastDet = Get-ChildItem $dashDir -File -Filter "details_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($lastDet) {
  $firstTwo = Get-Content $lastDet.FullName -TotalCount 2
  if (-not $firstTwo -or $firstTwo.Length -lt 2) {
    & (Join-Path $diagDir "extract_from_txt.ps1") -Repo $repo -ReportsDir $ReportsDir
  }
}
# 4) JUnit
& (Join-Path $diagDir "export_universal_junit.ps1") `
  -Repo $repo -ReportsDir $ReportsDir `
  -SuiteName "UniversalFindings" `
  -OutputDir "_otokodlama\reports\junit" `
  -GateOnFail:$GateOnFail -WarnAsSkip:$WarnAsSkip
# 5) Paketle
$bundle = Join-Path $bundleRoot ("bundle_" + $ts)
$null = New-Item -ItemType Directory -Force -Path $bundle | Out-Null
Copy-Item $reportsRoot -Destination $bundle -Recurse -Force | Out-Null
$pwDir = Join-Path $repo "playwright-report"
if (Test-Path $pwDir) { Copy-Item $pwDir -Destination (Join-Path $bundle "playwright-report") -Recurse -Force | Out-Null }
if ($Zip) {
  $zipPath = $bundle + ".zip"
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::CreateFromDirectory($bundle, $zipPath)
  Write-Host ("[BUNDLE] ZIP: " + $zipPath)
} else {
  Write-Host ("[BUNDLE] FOLDER: " + $bundle)
}
# 6) Özet
$totals = Get-ChildItem $dashDir -File -Filter "totals_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($totals) {
  $obj = Import-Csv $totals.FullName | Select-Object -First 1
  Write-Host ("[OZET] Son rapor: {0} | PASS={1} WARN={2} FAIL={3}" -f $obj.Timestamp,$obj.PASS,$obj.WARN,$obj.FAIL)
}