# === dashboard.ps1 - Sistem durumu ===
Write-Host "`n=== OTOKODLAMA DASHBOARD ===" -ForegroundColor Cyan

# 1. Quarantine özeti
. .\ops\quarantine.ps1
$all = Get-Quarantine
$success = ($all | Where-Object {$_.outcome -eq "Success"}).Count
$fail = ($all | Where-Object {$_.outcome -eq "Fail"}).Count
$total = $all.Count

Write-Host "`n[QUARANTINE]" -ForegroundColor Yellow
Write-Host "  Toplam: $total"
Write-Host "  Success: $success ($([math]::Round($success/$total*100))%)" -ForegroundColor Green
Write-Host "  Fail: $fail ($([math]::Round($fail/$total*100))%)" -ForegroundColor Red

# 2. Son 5 task
Write-Host "`n[SON 5 TASK]" -ForegroundColor Yellow
$all | Sort-Object {[DateTime]$_.last_attempt} -Descending | 
  Select-Object -First 5 | 
  Format-Table task_id, outcome, consecutive_fails, last_attempt -AutoSize

# 3. Patch inbox
Write-Host "`n[PATCH INBOX]" -ForegroundColor Yellow
$patches = Get-ChildItem _otokodlama\inbox\patch_*.zip -ErrorAction SilentlyContinue
Write-Host "  Toplam patch: $($patches.Count)"
if($patches){
  $patches | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | 
    ForEach-Object { Write-Host "  - $($_.Name) ($($_.Length) bytes)" -ForegroundColor Gray }
}

# 4. Sistem bilgisi
Write-Host "`n[SISTEM]" -ForegroundColor Yellow
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "  TLS: $([Net.ServicePointManager]::SecurityProtocol)"
Write-Host "  API Endpoint: $($env:AI_ENDPOINT)"

Write-Host "`n=== DASHBOARD TAMAMLANDI ===" -ForegroundColor Green
