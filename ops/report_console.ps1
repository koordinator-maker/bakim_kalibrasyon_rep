[CmdletBinding()]
param([string]$OutDir="_otokodlama\out")
$ErrorActionPreference="Stop"

if (-not (Test-Path $OutDir)) { throw "Out dir yok: $OutDir" }
$files = Get-ChildItem -Path $OutDir -Filter *.json -File | Sort-Object Name
if (-not $files) { Write-Host "[info] JSON sonu? dosyas? yok: $OutDir" -ForegroundColor Yellow; exit 0 }

Write-Host ""
Write-Host "==================== PIPELINE ?ZET RAPORU ====================" -ForegroundColor Cyan
Write-Host ("{0,-42}  {1,-5}    {2}" -f "Dosya","Sonu?","Detay") -ForegroundColor Gray
Write-Host "--------------------------------------------------------------" -ForegroundColor DarkGray

$okCount=0; $failCount=0; $errCount=0

foreach ($f in $files) {
  try {
    $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
    $status = "PASS"
    $detail = ""

    if ($j -and $j.PSObject.Properties.Name -contains 'ok') {
      if (-not $j.ok) { $status = "FAIL" }
    } elseif ($j -and $j.PSObject.Properties.Name -contains 'results') {
      $bad = $j.results | Where-Object { $_.ok -ne $true } | Select-Object -First 1
      if ($bad) { $status = "FAIL"; $detail = $bad.error }
    } else {
      $status = "ERROR"
      $detail = "Beklenmedik JSON format?"
    }

    if ($status -eq "FAIL" -and -not $detail) {
      $bad2 = $j.results | Where-Object { $_.error } | Select-Object -First 1
      if ($bad2) { $detail = $bad2.error }
    }

    if ($detail) {
      $detail = $detail -replace "`r?`n"," "
      if ($detail.Length -gt 80) { $detail = $detail.Substring(0,80) + "..." }
    }

    $namePad = $f.Name.PadRight(42)
    if ($status -eq "PASS") { $okCount++ ; Write-Host ("{0}  {1}    {2}" -f $namePad, $status.PadRight(5), $detail) -ForegroundColor Green }
    elseif ($status -eq "FAIL") { $failCount++; Write-Host ("{0}  {1}    {2}" -f $namePad, $status.PadRight(5), $detail) -ForegroundColor Red }
    else { $errCount++; Write-Host ("{0}  {1}    {2}" -f $namePad, $status.PadRight(5), $detail) -ForegroundColor Yellow }
  }
  catch {
    $errCount++
    $namePad = $f.Name.PadRight(42)
    Write-Host ("{0}  {1}    {2}" -f $namePad, "ERROR".PadRight(5), $_.Exception.Message) -ForegroundColor Yellow
  }
}

Write-Host "--------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("PASS: {0}   FAIL: {1}   ERROR: {2}" -f $okCount,$failCount,$errCount) -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""
