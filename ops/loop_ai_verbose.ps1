param(
  [string]$Mode = "direct",
  [int]$MaxRounds = 1,
  [string]$TaskId = "UH001"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot\quarantine.ps1"

Write-Host "=== LOOP AI - Verbose + Quarantine ==="
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
    Write-Host '[QUARANTINE] Task blocked - 3 consecutive fails' -ForegroundColor Red
    continue
  }
  
  # 1) Request JSON oluştur
  $reqPath = Join-Path $reqDir "$TaskId.json"
  if(!(Test-Path $reqPath)){
    Write-Host "Creating request JSON: $reqPath"
    @{task_id=$TaskId; files=@()} | ConvertTo-Json | Set-Content -Path $reqPath -Encoding UTF8
  }
  
  # 2) AI bridge çağır
  Write-Host "Calling bridge script..."
  $bridgeSuccess = $false
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
      if(-not $errors){ $bridgeSuccess = $true }
    } else {
      Write-Host "[TIMEOUT] AI bridge 60s timeout" -ForegroundColor Yellow
      Stop-Job $job; Remove-Job $job -Force
    }
  } catch {
    Write-Host "[ERROR] Bridge failed: $_" -ForegroundColor Red
  }
  
  # 3) Patch kontrol
  $patches = Get-ChildItem $inboxDir -Filter "patch_${TaskId}*.zip" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending
  
  $patchSuccess = $false
  if($patches){
    $patch = $patches[0]
    Write-Host "Patch found: $($patch.Name)" -ForegroundColor Green
    
    if(Test-Path $patchScript){
      Write-Host "Applying patch..."
      try {
        & powershell -ExecutionPolicy Bypass -File $patchScript -ZipPath $patch.FullName 2>&1 |
          ForEach-Object { Write-Host "  $_" }
        $patchSuccess = $true
      } catch {
        Write-Host "[ERROR] Patch apply failed: $_" -ForegroundColor Red
      }
    } else {
      Write-Host "[SKIP] lib_patch.ps1 not found" -ForegroundColor Yellow
    }
  } else {
    Write-Host "[WARN] Patch not found" -ForegroundColor Yellow
  }
  
  # 4) Quarantine güncelleme
  try {
    $roundSuccess = ($bridgeSuccess -and $patchSuccess)
    $outcome = if($roundSuccess){'Success'}else{'Fail'}
    Update-Quarantine -TaskId $TaskId -Outcome $outcome
    Write-Host "Quarantine: $TaskId -> $outcome" -ForegroundColor Gray
  } catch {
    Write-Warning "Quarantine update failed: $_"
  }
  
  Start-Sleep -Seconds 2
}

Write-Host "`n=== LOOP COMPLETE ===" -ForegroundColor Green
