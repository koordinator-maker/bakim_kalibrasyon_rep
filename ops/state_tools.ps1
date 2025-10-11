param(
  # Varsayılan yol, bu dosyanın (ops/) yanına state.json olarak ayarlanır
  [string]$StatePath = ""
)

$ErrorActionPreference = "Stop"

# --- Yol yardımcıları ---
$__ThisFile   = $MyInvocation.MyCommand.Path
$__ScriptRoot = Split-Path -Parent $__ThisFile
if ([string]::IsNullOrWhiteSpace($StatePath)) {
  $StatePath = Join-Path $__ScriptRoot "state.json"
}

function _Is-Hashtable { param($x) return ($x -is [hashtable]) }
function _Is-PSObj     { param($x) return ($x -is [pscustomobject]) }

function _Ensure-Dir {
  param([Parameter(Mandatory=$true)][string]$Path)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

function _Ensure-Prop {
  param($Obj,[string]$Name,$Default=$null)
  if (_Is-Hashtable $Obj) { if (-not $Obj.ContainsKey($Name)) { $Obj[$Name]=$Default }; return }
  if (-not $Obj.PSObject.Properties[$Name]) { Add-Member -InputObject $Obj -MemberType NoteProperty -Name $Name -Value $Default }
}

function _Set-Prop {
  param($Obj,[string]$Name,$Value)
  if (_Is-Hashtable $Obj) { $Obj[$Name]=$Value; return }
  if (-not $Obj.PSObject.Properties[$Name]) { Add-Member -InputObject $Obj -MemberType NoteProperty -Name $Name -Value $Value }
  else { $Obj.$Name = $Value }
}

# Map benzeri alanlara anahtar/değer yaz (Hashtable veya PSCustomObject fark etmeksizin)
function _Map-Set {
  param($Map,[string]$Key,$Value)
  if (_Is-Hashtable $Map) { $Map[$Key] = $Value; return }
  if (-not $Map.PSObject.Properties[$Key]) { Add-Member -InputObject $Map -MemberType NoteProperty -Name $Key -Value $Value }
  else { $Map.$Key = $Value }
}

# Map benzeri alanın anahtarlarını döndür
function _Map-Keys {
  param($Map)
  if (_Is-Hashtable $Map) { return $Map.Keys }
  return ($Map.PSObject.Properties | Select-Object -ExpandProperty Name)
}

function Get-State {
  param([string]$Path = $StatePath)
  try {
    if (Test-Path $Path) {
      $s = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
      _Ensure-Prop $s 'project' ''
      _Ensure-Prop $s 'repo' ''
      _Ensure-Prop $s 'pipeline' (@{ stage="validate_ui_pages"; history=@() })
      _Ensure-Prop $s 'tests'    (@{ results=@{}; summary=@{ passed=0; failed=0; last_run="" } })
      _Ensure-Prop $s 'pending_actions' @()
      _Ensure-Prop $s 'last_updated'    ""
      _Ensure-Prop $s.pipeline 'stage'   'validate_ui_pages'
      _Ensure-Prop $s.pipeline 'history' @()
      _Ensure-Prop $s.tests    'results' @{}
      _Ensure-Prop $s.tests    'summary' (@{ passed=0; failed=0; last_run="" })
      _Ensure-Prop $s.tests.summary 'passed'   0
      _Ensure-Prop $s.tests.summary 'failed'   0
      _Ensure-Prop $s.tests.summary 'last_run' ""
      return $s
    }
  } catch { }

  return [pscustomobject]@{
    project=""
    repo=""
    pipeline=@{ stage="validate_ui_pages"; history=@() }
    tests=@{ results=@{}; summary=@{ passed=0; failed=0; last_run="" } }
    pending_actions=@()
    last_updated=""
  }
}

function Save-State {
  param([Parameter(Mandatory=$true)]$State,[string]$Path=$StatePath)
  _Ensure-Prop $State 'last_updated' ""
  _Set-Prop    $State 'last_updated' ((Get-Date).ToString("s"))
  _Ensure-Dir  -Path $Path
  $json = $State | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($Path,$json,[Text.UTF8Encoding]::new($false))
}

function Update-TestResult {
  param(
    [Parameter(Mandatory=$true)][string]$Key,
    [ValidateSet("PASSED","FAILED")][string]$Status,
    [hashtable]$Metrics,[hashtable]$Artifacts,
    [string]$StatePathParam = $StatePath
  )
  $st = Get-State -Path $StatePathParam
  _Ensure-Prop $st 'tests' (@{ results=@{}; summary=@{passed=0;failed=0;last_run=""} })
  _Ensure-Prop $st.tests 'results' @{}
  _Ensure-Prop $st.tests 'summary' (@{ passed=0; failed=0; last_run="" })
  if (-not $Metrics)   { $Metrics   = @{} }
  if (-not $Artifacts) { $Artifacts = @{} }

  $entry = @{
    status=$Status; metrics=$Metrics; artifacts=$Artifacts; ts=(Get-Date).ToString("s")
  }
  _Map-Set $st.tests.results $Key $entry

  $passed=0; $failed=0
  foreach($k in (_Map-Keys $st.tests.results)){
    $it = if (_Is-Hashtable $st.tests.results) { $st.tests.results[$k] } else { $st.tests.results.$k }
    if($it.status -eq "PASSED"){$passed++}else{$failed++}
  }
  _Set-Prop $st.tests.summary 'passed'   $passed
  _Set-Prop $st.tests.summary 'failed'   $failed
  _Set-Prop $st.tests.summary 'last_run' ((Get-Date).ToString("s"))

  Save-State -State $st -Path $StatePathParam
}

function Add-PendingAction {
  param(
    [Parameter(Mandatory=$true)][string]$Id,
    [Parameter(Mandatory=$true)][string]$Type,
    [Parameter(Mandatory=$true)][string]$Detail,
    [string]$DueStage="",
    [string]$StatePathParam = $StatePath
  )
  $st = Get-State -Path $StatePathParam
  _Ensure-Prop $st 'pending_actions' @()
  $st.pending_actions += @{ id=$Id; type=$Type; detail=$Detail; due_stage=$DueStage; ts=(Get-Date).ToString("s"); status="open" }
  Save-State -State $st -Path $StatePathParam
}

function Advance-Pipeline {
  param([Parameter(Mandatory=$true)][string]$ToStage,[string]$Hint="",[string]$StatePathParam=$StatePath)
  $st = Get-State -Path $StatePathParam
  _Ensure-Prop $st 'pipeline' (@{ stage="validate_ui_pages"; history=@() })
  _Ensure-Prop $st.pipeline 'stage' "validate_ui_pages"
  _Ensure-Prop $st.pipeline 'history' @()
  $st.pipeline.history += @{ from=$st.pipeline.stage; to=$ToStage; hint=$Hint; ts=(Get-Date).ToString("s") }
  _Set-Prop $st.pipeline 'stage' $ToStage
  Save-State -State $st -Path $StatePathParam
}
