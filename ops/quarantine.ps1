# === quarantine.ps1 (PS5.1 - script mode) ===
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:QuarantineFile = Join-Path $script:RepoRoot "_otokodlama\quarantine.json"

function Get-Quarantine {
  param([string]$TaskId)
  
  if(!(Test-Path $script:QuarantineFile)){ return @() }
  
  try {
    $data = Get-Content $script:QuarantineFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if(-not $data){ return @() }
    if($data -isnot [array]){ $data = @($data) }
    
    if($TaskId){
      return $data | Where-Object { $_.task_id -eq $TaskId }
    }
    return $data
  } catch {
    Write-Warning "Quarantine dosyasi okunamadi: $_"
    return @()
  }
}

function Update-Quarantine {
  param(
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][ValidateSet('Success','Fail','Timeout')][string]$Outcome
  )
  
  $all = @()
  if(Test-Path $script:QuarantineFile){
    try {
      $all = Get-Content $script:QuarantineFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if(-not $all){ $all = @() }
      if($all -isnot [array]){ $all = @($all) }
    } catch {
      Write-Warning "Quarantine dosyasi bozuk, sifirlaniyor"
      $all = @()
    }
  }
  
  # Mevcut kaydı bul
  $existing = $null
  $index = -1
  for($i=0; $i -lt $all.Count; $i++){
    if($all[$i].task_id -eq $TaskId){
      $existing = $all[$i]
      $index = $i
      break
    }
  }
  
  if($existing){
    # Mevcut kayıt - yeni nesne oluştur
    $failCount = 0
    if($existing.PSObject.Properties.Name -contains 'consecutive_fails'){
      $failCount = [int]$existing.consecutive_fails
    }
    
    if($Outcome -ne 'Success'){
      $failCount++
    } else {
      $failCount = 0
    }
    
    $updated = [PSCustomObject]@{
      task_id           = $TaskId
      outcome           = $Outcome
      consecutive_fails = $failCount
      first_attempt     = $existing.first_attempt
      last_attempt      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    }
    
    $all[$index] = $updated
  } else {
    # Yeni kayıt
    $newEntry = [PSCustomObject]@{
      task_id           = $TaskId
      outcome           = $Outcome
      consecutive_fails = if($Outcome -eq 'Success'){ 0 } else { 1 }
      first_attempt     = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
      last_attempt      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    }
    $all = @($all) + $newEntry
  }
  
  # Kaydet
  $dir = Split-Path $script:QuarantineFile -Parent
  if(!(Test-Path $dir)){ New-Item -ItemType Directory -Force $dir | Out-Null }
  
  $all | ConvertTo-Json -Depth 5 | Set-Content -Path $script:QuarantineFile -Encoding UTF8
}

function Test-QuarantineBlock {
  param(
    [Parameter(Mandatory)][string]$TaskId,
    [int]$MaxFails = 3
  )
  
  $entry = Get-Quarantine -TaskId $TaskId
  if(-not $entry){ return $false }
  
  if($entry.PSObject.Properties.Name -contains 'consecutive_fails'){
    return ([int]$entry.consecutive_fails -ge $MaxFails)
  }
  return $false
}

# Export yok (script mode)
