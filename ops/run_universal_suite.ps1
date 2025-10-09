param(
  [string]$Repo = ".",
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [string]$EntryPath = "/admin/",
  [string]$ReportsDir = "_otokodlama\reports",
  [string]$BundleDir  = "_otokodlama\bundle",
  [switch]$Zip = $true
)
Set-StrictMode -Version Latest; $ErrorActionPreference="Stop"
$repo = Resolve-Path $Repo; Set-Location $repo
$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
$reportsRoot = Join-Path $repo $ReportsDir
$bundleRoot  = Join-Path $repo $BundleDir
$diagDir     = Join-Path $repo "ops\diagnostics"
$null = New-Item -ItemType Directory -Force -Path $reportsRoot,$bundleRoot,$diagDir | Out-Null
# 1) Rapor
powershell -ExecutionPolicy Bypass -File (Join-Path $diagDir "report_universal.ps1") -Repo $repo -OutDir $ReportsDir -BaseUrl $BaseUrl -EntryPath $EntryPath
# 2) Dashboard
powershell -ExecutionPolicy Bypass -File (Join-Path $diagDir "build_universal_dashboard.ps1") -Repo $repo -ReportsDir $ReportsDir
# 3) JUnit
powershell -ExecutionPolicy Bypass -File (Join-Path $diagDir "export_universal_junit.ps1") -Repo $repo -ReportsDir $ReportsDir -SuiteName "UniversalFindings" -OutputDir "_otokodlama\reports\junit" -GateOnFail -WarnAsSkip
# 4) Paketle (rapor+playwright-report)
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
# Konsol özeti
$dashDir = Join-Path $reportsRoot "dashboard"
$totals = Get-ChildItem $dashDir -File -Filter "totals_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($totals) {
  $obj = Import-Csv $totals.FullName | Select-Object -First 1
  Write-Host ("[ÖZET] Son rapor: {0} | PASS={1} WARN={2} FAIL={3}" -f $obj.Timestamp,$obj.PASS,$obj.WARN,$obj.FAIL)
}