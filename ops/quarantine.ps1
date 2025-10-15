Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-Env([string]$name,[string]$fallback){
  # PS5.1 güvenli env okuma (Process→User→Machine)
  $v = [Environment]::GetEnvironmentVariable($name,'Process')
  if([string]::IsNullOrWhiteSpace($v)){ $v = [Environment]::GetEnvironmentVariable($name,'User') }
  if([string]::IsNullOrWhiteSpace($v)){ $v = [Environment]::GetEnvironmentVariable($name,'Machine') }
  if([string]::IsNullOrWhiteSpace($v)){ return $fallback } else { return $v }
}

function Initialize-Quarantine {
  param([string]$Root = "_otokodlama")
  $stateDir = Join-Path $Root "state"
  $qtDir    = Join-Path $Root "quarantine"
  $repDir   = Join-Path $Root "reports\notify"
  New-Item -ItemType Directory -Force $stateDir,$qtDir,$repDir | Out-Null
  $state = Join-Path $stateDir "quarantine_state.json"
  if(-not (Test-Path $state)){ '{}' | Set-Content -Encoding utf8 -Path $state }
  return @{ StatePath=$state; QtDir=$qtDir; RepDir=$repDir }
}

function Update-Quarantine {
  param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [Parameter(Mandatory=$true)][ValidateSet('Success','Fail')]$Outcome,
    [int]$Threshold = $( [int](Get-Env 'QUARANTINE_THRESHOLD' '15') )
  )
  $meta = Initialize-Quarantine
  $statePath = $meta.StatePath
  $obj = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue
  if(-not $obj){ $obj = @{} }

  if(-not $obj.ContainsKey($TaskId)){ $obj.$TaskId = @{ fails = 0; quarantined = $false } }
  $rec = $obj.$TaskId

  if($Outcome -eq 'Success'){ $rec.fails = 0 } else { $rec.fails = [int]$rec.fails + 1 }

  $now = Get-Date
  $qJustNow = $false
  if((-not $rec.quarantined) -and $rec.fails -ge $Threshold){
    $rec.quarantined = $true
    $qJustNow = $true
    $csv = Join-Path $meta.QtDir "quarantine.csv"
    $line = '{0},{1},{2},{3}' -f $now.ToString('s'),$TaskId,$rec.fails,$Threshold
    Add-Content -Encoding utf8 -Path $csv -Value $line
    $sum = Join-Path $meta.RepDir ("ai_queue_summary_{0}.txt" -f $now.ToString('yyyyMMdd'))
    Add-Content -Encoding utf8 -Path $sum -Value ("[{0}] QUARANTINE → {1} (fails={2}/{3})" -f $now.ToString('HH:mm:ss'),$TaskId,$rec.fails,$Threshold)
  }

  ($obj | ConvertTo-Json -Depth 5) | Set-Content -Encoding utf8 -Path $statePath

  [pscustomobject]@{
    TaskId=$TaskId; Fails=[int]$rec.fails; Threshold=$Threshold
    Quarantined=[bool]$rec.quarantined; JustQuarantined=$qJustNow
  }
}
