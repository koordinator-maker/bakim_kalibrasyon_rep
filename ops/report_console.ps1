param(
  [string]$OutDir = ".\_otokodlama\out"
)

$ErrorActionPreference = "Stop"

$files = Get-ChildItem -Path $OutDir -Filter "*.json" -ErrorAction Stop
Write-Host ""
Write-Host "==================== PIPELINE ÖZET RAPORU ====================" -ForegroundColor Cyan
Write-Host "Dosya                     Sonuç    Detay"
Write-Host "--------------------------------------------------------------"

$totalPass = 0
$totalFail = 0
$totalError = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    $result = ""
    $detail = ""

    if (-not $content) {
        $result = "ERROR"
        $detail = "JSON Parse Hatası"
        $totalError++
    }
    elseif ($content.status -eq "PASS") {
        $result = "PASS"
        $totalPass++
    }
    elseif ($content.status -eq "FAIL") {
        $result = "FAIL"
        $detail = $content.error -replace '\r?\n.*', '' # İlk satırı al
        $totalFail++
    }
    else {
        $result = "UNKNOW"
        $totalError++
    }

    "{0,-30} {1,-8} {2}" -f $file.Name, $result, $detail
}

Write-Host "--------------------------------------------------------------"
Write-Host "PASS: $totalPass    FAIL: $totalFail    ERROR: $totalError" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Cyan
