param(
  [string]$StatePath = "ops/state.json"
)

function Get-State {
  param([string]$Path = $StatePath)
  if (Test-Path $Path) {
    try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { }
  }
  # boş state
  return [pscustomobject]@{
    project   = ""
    repo      = ""
    pipeline  = @{
      stage   = "validate_ui_pages"
      history = @()
    }
    tests     = @{
      results = @{}
      summary = @{
        passed = 0
        failed = 0
        last_run = ""
      }
    }
    pending_actions = @()
    last_updated = ""
  }
}

function Save-State {
  param(
    [Parameter(Mandatory=$true)]$State,
    [string]$Path = $StatePath
  )
  $State.last_updated = (Get-Date).ToString("s")
  $json = $State | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Update-TestResult {
  param(
    [string]$Key,
    [ValidateSet("PASSED","FAILED")][string]$Status,
    [hashtable]$Metrics,
    [hashtable]$Artifacts,
    [string]$StatePathParam = $StatePath
  )
  $st = Get-State -Path $StatePathParam
  if (-not $st.tests) { $st | Add-Member -Name tests -MemberType NoteProperty -Value (@{ results=@{}; summary=@{passed=0;failed=0;last_run=""} }) }
  if (-not $st.tests.results) { $st.tests.results = @{} }

  $st.tests.results[$Key] = @{
    status    = $Status
    metrics   = $Metrics
    artifacts = $Artifacts
    ts        = (Get-Date).ToString("s")
  }

  # özet
  $passed = 0; $failed = 0
  foreach ($k in $st.tests.results.Keys) {
    if ($st.tests.results[$k].status -eq "PASSED") { $passed++ } else { $failed++ }
  }
  $st.tests.summary = @{
    passed   = $passed
    failed   = $failed
    last_run = (Get-Date).ToString("s")
  }

  Save-State -State $st -Path $StatePathParam
}

function Add-PendingAction {
  param(
    [string]$Id,
    [string]$Type,
    [string]$Detail,
    [string]$DueStage,
    [string]$StatePathParam = $StatePath
  )
  $st = Get-State -Path $StatePathParam
  if (-not $st.pending_actions) { $st.pending_actions = @() }
  $st.pending_actions += @{
    id       = $Id
    type     = $Type
    detail   = $Detail
    due_stage= $DueStage
    ts       = (Get-Date).ToString("s")
    status   = "open"
  }
  Save-State -State $st -Path $StatePathParam
}

function Advance-Pipeline {
  param(
    [Parameter(Mandatory=$true)][string]$ToStage,
    [string]$Hint = "",
    [string]$StatePathParam = $StatePath
  )
  $st = Get-State -Path $StatePathParam
  if (-not $st.pipeline) { $st.pipeline = @{ stage="validate_ui_pages"; history=@() } }
  if (-not $st.pipeline.history) { $st.pipeline.history = @() }
  $st.pipeline.history += @{
    from = $st.pipeline.stage
    to   = $ToStage
    hint = $Hint
    ts   = (Get-Date).ToString("s")
  }
  $st.pipeline.stage = $ToStage
  Save-State -State $st -Path $StatePathParam
}
