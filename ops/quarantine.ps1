$ErrorActionPreference = "Stop"
$Root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$StateDir = Join-Path $Root "_otokodlama\state"
$QueueDir = Join-Path $Root "_otokodlama\ai_queue"
$QuaranDir= Join-Path $Root "_otokodlama\quarantine"
$NotifyDir= Join-Path $Root "_otokodlama\reports\notify"
New-Item -ItemType Directory -Force $StateDir,$QueueDir,$QuaranDir,$NotifyDir | Out-Null
$QPath  = Join-Path $StateDir "quarantine.json"
$Events = Join-Path $QueueDir "events.jsonl"
function _W([string]$p,[string]$t){ $e=[Text.UTF8Encoding]::new($false); [IO.File]::WriteAllText($p,$t,$e) }
function _R([string]$p){ if(Test-Path $p){ Get-Content $p -Raw -Encoding UTF8 } else { "" } }
function Load-Q { if(Test-Path $QPath){ (_R $QPath | ConvertFrom-Json) } else { @{ tasks=@{} } } }
function Save-Q($q){ _W $QPath (($q|ConvertTo-Json -Depth 10)) }
function Is-Quarantined([string]$TaskId){ $q=Load-Q; return [bool]($q.tasks.$TaskId -and $q.tasks.$TaskId.quarantined) }
function Add-AIEvent([string]$TaskId,[string]$Kind,[string]$Detail,[hashtable]$Meta=@{}){ $o=@{taskId=$TaskId;kind=$Kind;detail=$Detail;meta=$Meta;ts=(Get-Date).ToString("s")}; Add-Content -LiteralPath $Events -Value (($o|ConvertTo-Json -Depth 8)) -Encoding UTF8 }
function Inc-Attempt([string]$TaskId,[bool]$Pass){
  if([string]::IsNullOrWhiteSpace($TaskId)){ return @{} }
  $q=Load-Q; if(-not $q.tasks){ $q.tasks=@{} }
  if(-not $q.tasks.$TaskId){ $q.tasks.$TaskId=@{attempts=0;fails=0;quarantined=$false;first_ts="";last_ts=""} }
  $it=$q.tasks.$TaskId; if(-not $it.first_ts){ $it.first_ts=(Get-Date).ToString("s") }
  $it.attempts++; if(-not $Pass){ $it.fails++ }; $it.last_ts=(Get-Date).ToString("s")
  if(-not $Pass -and $it.fails -ge 15 -and -not $it.quarantined){
    $it.quarantined=$true; _W (Join-Path $QuaranDir ("$TaskId.marker")) ("quarantined "+(Get-Date).ToString("s"))
    Add-AIEvent -TaskId $TaskId -Kind "quarantine" -Detail "15 fail eşiği aşıldı" -Meta @{fails=$it.fails;attempts=$it.attempts}
  }
  Save-Q $q; return $it
}
function Emit-Queue-Summary {
  $q=Load-Q; $rows=@(); foreach($k in $q.tasks.Keys){ $t=$q.tasks.$k; $rows+=[pscustomobject]@{TaskId=$k;Attempts=$t.attempts;Fails=$t.fails;Quarantine=$t.quarantined} }
  $top=$rows|Sort-Object Fails -Descending|Select-Object -First 5
  $lines=@("# AI Kuyruğu / Karantina Özeti",(Get-Date).ToString("s"),"")
  foreach($r in $top){ $lines+=("- {0}  (fails={1}, attempts={2}, quarantine={3})" -f $r.TaskId,$r.Fails,$r.Attempts,$r.Quarantine) }
  $out=Join-Path $NotifyDir ("summary_ai_queue_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".txt")
  _W $out ($lines -join "`r`n"); return $out
}