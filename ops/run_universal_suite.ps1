# === run_universal_suite.ps1 - Tek komutta tum rapor akisi ===
param([string]$TaskId = "AUTO")

Write-Host "`n=== UNIVERSAL SUITE STARTING ===" -ForegroundColor Cyan

# 1. Report
Write-Host "`n[1/4] Report olusturuluyor..." -ForegroundColor Yellow
if(Test-Path ops\diagnostics\report_universal.ps1){
    & .\ops\diagnostics\report_universal.ps1 -TaskId $TaskId
}

# 2. Dashboard
Write-Host "`n[2/4] Dashboard olusturuluyor..." -ForegroundColor Yellow
if(Test-Path ops\diagnostics\build_universal_dashboard.ps1){
    & .\ops\diagnostics\build_universal_dashboard.ps1
}

# 3. JUnit
Write-Host "`n[3/4] JUnit XML export..." -ForegroundColor Yellow
if(Test-Path ops\diagnostics\export_universal_junit.ps1){
    & .\ops\diagnostics\export_universal_junit.ps1
}

# 4. Bundle
Write-Host "`n[4/4] Bundle olusturuluyor..." -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundlePath = "_otokodlama\bundle\bundle_${timestamp}.zip"

if(!(Test-Path _otokodlama\bundle)){ New-Item -ItemType Directory -Force _otokodlama\bundle | Out-Null }

$itemsToBundle = @(
    "_otokodlama\reports\*.txt",
    "_otokodlama\reports\*.csv",
    "dashboard\index.md"
)

$tempBundleDir = "_otokodlama\temp\bundle_${timestamp}"
New-Item -ItemType Directory -Force $tempBundleDir | Out-Null

foreach($pattern in $itemsToBundle){
    Get-ChildItem $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName $tempBundleDir -Force
    }
}

Compress-Archive -Path "$tempBundleDir\*" -DestinationPath $bundlePath -Force
Remove-Item $tempBundleDir -Recurse -Force
Write-Host "[OK] Bundle: $bundlePath" -ForegroundColor Green

Write-Host "`n=== SUITE COMPLETE ===" -ForegroundColor Green
