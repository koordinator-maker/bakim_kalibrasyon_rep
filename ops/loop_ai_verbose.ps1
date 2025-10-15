param(
  [string]$Mode = "direct",
  [int]$MaxRounds = 1,
  [string]$TaskId = "UH001"
)
Set-StrictMode -Version Latest
. "$PSScriptRoot\quarantine.ps1"
$ErrorActionPreference='Stop'

Write-Host "=== LOOP AI (Verbose) ==="
Write-Host "Mode: $Mode | MaxRounds: $MaxRounds | TaskId: $TaskId"

# Mutlak yollar (PS5.1 uyumlu)
$root = $PSScriptRoot
if(-not $root){ $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if(-not $root){ $root = (Get-Location).Path }

$repoRoot     = Split-Path -Parent $root
$bridgeScript = Join-Path $root "ai_bridge_http.ps1"
$patchScript  = Join-Path $root "lib_patch.ps1"
$reqDir       = Join-Path $repoRoot "_otokodlama\out"
$inboxDir     = Join-Path $repoRoot "_otokodlama\inbox"

Write-Host "Repo root: $repoRoot"
Write-Host "Bridge script: $bridgeScript"

if(!(Test-Path $bridgeScript)){ throw "ai_bridge_http.ps1 bulunamadi: $bridgeScript" }
if(!(Test-Path $reqDir)){ New-Item -ItemType Directory -Force $reqDir | Out-Null }
if(!(Test-Path $inboxDir)){ New-Item -ItemType Directory -Force $inboxDir | Out-Null }

for($i=1; $i -le $MaxRounds; $i++){
  Write-Host "`n=== ROUND $i/$MaxRounds ===" -ForegroundColor Cyan

  # Quarantine block kontrolü
  if(Test-QuarantineBlock -TaskId $TaskId -MaxFails 3){
    Write-Host '[QUARANTINE BLOCK] Task $TaskId blocked (3 or more consecutive fails)' -ForegroundColor Red
    continue
  }
  
  # 1) Request JSON oluştur
  $reqPath = Join-Path $reqDir "$TaskId.json"
  if(!(Test-Path $reqPath)){
    Write-Host "Creating request JSON: $reqPath"
    @{task_id=$TaskId; files=@()} | ConvertTo-Json | Set-Content -Path $reqPath -Encoding UTF8
  }
  
  # 2) AI bridge çağır (mutlak yol ile)
  Write-Host "Calling bridge script..."
  try {
    $job = Start-Job -ScriptBlock {
      param($Script, $TaskId, $ReqDir, $InboxDir)
      & powershell -ExecutionPolicy Bypass -File $Script `
        -RequestsDir $ReqDir -InboxDir $InboxDir -TaskId $TaskId 2>&1
    } -ArgumentList $bridgeScript, $TaskId, $reqDir, $inboxDir
    
    if($job | Wait-Job -Timeout 60){
      $output = Receive-Job $job
      Write-Host "Bridge output:"
      $output | ForEach-Object { Write-Host "  $_" }
      Remove-Job $job -Force
      
      # Hata kontrolü
      $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
      if($errors){
        Write-Host "[ERROR] Bridge hata verdi" -ForegroundColor Red
        continue
      }
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
    
    if(Test-Path $patchScript){
      Write-Host "Applying patch..."
      try {
        & powershell -ExecutionPolicy Bypass -File $patchScript -ZipPath $patch.FullName 2>&1 |
          ForEach-Object { Write-Host "  $_" }
      } catch {
        Write-Host "[ERROR] Patch uygulamasi basarisiz: $_" -ForegroundColor Red
      }
    } else {
      Write-Host "[SKIP] lib_patch.ps1 bulunamadi: $patchScript" -ForegroundColor Yellow
    }
  } else {
    Write-Host "[WARN] Patch bulunamadi" -ForegroundColor Yellow
  }
  
  
  # Quarantine outcome güncelleme
  try {
    $roundSuccess = ($patches -and $patches.Count -gt 0)
    $outcome = if($roundSuccess){'Success'}else{'Fail'}
    Update-Quarantine -TaskId $TaskId -Outcome $outcome
    Write-Host "Quarantine: $TaskId -> $outcome" -ForegroundColor Gray
  } catch {
    Write-Warning "Quarantine guncelleme hatasi: param(
  [string]$Mode = "direct",
  [int]$MaxRounds = 1,
  [string]$TaskId = "UH001"
)
Set-StrictMode -Version Latest
. "$PSScriptRoot\quarantine.ps1"
$ErrorActionPreference='Stop'

Write-Host "=== LOOP AI (Verbose) ==="
Write-Host "Mode: $Mode | MaxRounds: $MaxRounds | TaskId: $TaskId"

# Mutlak yollar (PS5.1 uyumlu)
$root = $PSScriptRoot
if(-not $root){ $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if(-not $root){ $root = (Get-Location).Path }

$repoRoot     = Split-Path -Parent $root
$bridgeScript = Join-Path $root "ai_bridge_http.ps1"
$patchScript  = Join-Path $root "lib_patch.ps1"
$reqDir       = Join-Path $repoRoot "_otokodlama\out"
$inboxDir     = Join-Path $repoRoot "_otokodlama\inbox"

Write-Host "Repo root: $repoRoot"
Write-Host "Bridge script: $bridgeScript"

if(!(Test-Path $bridgeScript)){ throw "ai_bridge_http.ps1 bulunamadi: $bridgeScript" }
if(!(Test-Path $reqDir)){ New-Item -ItemType Directory -Force $reqDir | Out-Null }
if(!(Test-Path $inboxDir)){ New-Item -ItemType Directory -Force $inboxDir | Out-Null }

for($i=1; $i -le $MaxRounds; $i++){
  Write-Host "`n=== ROUND $i/$MaxRounds ===" -ForegroundColor Cyan

  # Quarantine block kontrolü
  if(Test-QuarantineBlock -TaskId $TaskId -MaxFails 3){
    Write-Host '[QUARANTINE BLOCK] Task $TaskId blocked (3 or more consecutive fails)' -ForegroundColor Red
    continue
  }
  
  # 1) Request JSON oluştur
  $reqPath = Join-Path $reqDir "$TaskId.json"
  if(!(Test-Path $reqPath)){
    Write-Host "Creating request JSON: $reqPath"
    @{task_id=$TaskId; files=@()} | ConvertTo-Json | Set-Content -Path $reqPath -Encoding UTF8
  }
  
  # 2) AI bridge çağır (mutlak yol ile)
  Write-Host "Calling bridge script..."
  try {
    $job = Start-Job -ScriptBlock {
      param($Script, $TaskId, $ReqDir, $InboxDir)
      & powershell -ExecutionPolicy Bypass -File $Script `
        -RequestsDir $ReqDir -InboxDir $InboxDir -TaskId $TaskId 2>&1
    } -ArgumentList $bridgeScript, $TaskId, $reqDir, $inboxDir
    
    if($job | Wait-Job -Timeout 60){
      $output = Receive-Job $job
      Write-Host "Bridge output:"
      $output | ForEach-Object { Write-Host "  $_" }
      Remove-Job $job -Force
      
      # Hata kontrolü
      $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
      if($errors){
        Write-Host "[ERROR] Bridge hata verdi" -ForegroundColor Red
        continue
      }
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
    
    if(Test-Path $patchScript){
      Write-Host "Applying patch..."
      try {
        & powershell -ExecutionPolicy Bypass -File $patchScript -ZipPath $patch.FullName 2>&1 |
          ForEach-Object { Write-Host "  $_" }
      } catch {
        Write-Host "[ERROR] Patch uygulamasi basarisiz: $_" -ForegroundColor Red
      }
    } else {
      Write-Host "[SKIP] lib_patch.ps1 bulunamadi: $patchScript" -ForegroundColor Yellow
    }
  } else {
    Write-Host "[WARN] Patch bulunamadi" -ForegroundColor Yellow
  }
  
  Start-Sleep -Seconds 2
}

Write-Host "`n=== LOOP COMPLETE ===" -ForegroundColor Green

"
  }
  Start-Sleep -Seconds 2
}

Write-Host "`n=== LOOP COMPLETE ===" -ForegroundColor Green



