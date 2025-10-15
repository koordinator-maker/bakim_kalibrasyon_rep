param(
  [string]$Mode = "direct",
  [int]$MaxRounds = 1,
  [string]$TaskId = "UH001"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

Write-Host "=== LOOP AI (Verbose) ==="
Write-Host "Mode: $Mode | MaxRounds: $MaxRounds | TaskId: $TaskId"

# Config
$reqDir = "_otokodlama\out"
$inboxDir = "_otokodlama\inbox"

if(!(Test-Path $reqDir)){ New-Item -ItemType Directory -Force $reqDir | Out-Null }
if(!(Test-Path $inboxDir)){ New-Item -ItemType Directory -Force $inboxDir | Out-Null }

for($i=1; $i -le $MaxRounds; $i++){
  Write-Host "`n=== ROUND $i/$MaxRounds ===" -ForegroundColor Cyan
  
  # 1) Request JSON oluştur
  $reqPath = Join-Path $reqDir "$TaskId.json"
  if(!(Test-Path $reqPath)){
    Write-Host "Creating request JSON: $reqPath"
    @{task_id=$TaskId; files=@()} | ConvertTo-Json | Set-Content -Path $reqPath -Encoding UTF8
  }
  
  # 2) AI bridge çağır (timeout ile)
  Write-Host "Calling ai_bridge_http.ps1 ..."
  try {
    $job = Start-Job -ScriptBlock {
      param($TaskId)
      powershell -ExecutionPolicy Bypass -File .\ops\ai_bridge_http.ps1 -TaskId $TaskId
    } -ArgumentList $TaskId
    
    if($job | Wait-Job -Timeout 60){
      $output = Receive-Job $job
      Write-Host "Bridge output: $output"
      Remove-Job $job -Force
    } else {
      Write-Host "[TIMEOUT] AI bridge 60s icinde tamamlanmadi" -ForegroundColor Yellow
      Stop-Job $job; Remove-Job $job -Force
      continue
    }
  } catch {
    Write-Host "[ERROR] Bridge failed: $_" -ForegroundColor Red
    continue
  }
  
  # 3) Patch kontrol
  $patches = Get-ChildItem $inboxDir -Filter "patch_${TaskId}*.zip" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending
  
  if($patches){
    $patch = $patches[0]
    Write-Host "Patch bulundu: $($patch.Name)" -ForegroundColor Green
    
    if(Test-Path .\ops\lib_patch.ps1){
      Write-Host "Applying patch..."
      try {
        powershell -ExecutionPolicy Bypass -File .\ops\lib_patch.ps1 -ZipPath $patch.FullName
      } catch {
        Write-Host "[ERROR] Patch uygulamasi basarisiz: $_" -ForegroundColor Red
      }
    } else {
      Write-Host "[SKIP] lib_patch.ps1 bulunamadi" -ForegroundColor Yellow
    }
  } else {
    Write-Host "[WARN] Patch bulunamadi" -ForegroundColor Yellow
  }
  
  Start-Sleep -Seconds 2
}

Write-Host "`n=== LOOP COMPLETE ===" -ForegroundColor Green
