# === run_local_e2e.ps1 - Basit Test Runner ===
$ErrorActionPreference = 'Continue'
$repo = $PWD

Write-Host "`n=== PLAYWRIGHT TESTS BAŞLIYOR ===" -ForegroundColor Cyan

# Ortam değişkenleri
$env:BASE_URL = 'http://127.0.0.1:8010'
$env:ADMIN_USER = 'admin'
$env:ADMIN_PASS = 'admin123!'

# Testleri çalıştır
npx playwright test --config=playwright.all.config.cjs --headed

$exitCode = $LASTEXITCODE

Write-Host "`n=== TESTS TAMAMLANDI (Exit Code: $exitCode) ===" -ForegroundColor $(if($exitCode -eq 0){'Green'}else{'Yellow'})

# HTML raporu aç
$htmlReport = Get-ChildItem "$repo\playwright-report" -Recurse -Filter "index.html" |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1

if($htmlReport){
    Write-Host "`n[INFO] HTML Rapor:" -ForegroundColor Cyan
    Write-Host "  $($htmlReport.FullName)" -ForegroundColor White
    
    # Otomatik aç (opsiyonel)
    # Start-Process $htmlReport.FullName
}

exit $exitCode
