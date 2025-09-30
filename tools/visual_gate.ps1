param([string]$State="ops\state.json")
$ErrorActionPreference="Stop"

# Repo kÃ¶kÃ¼: tools klasÃ¶rÃ¼nÃ¼n bir Ã¼stÃ¼
$repoRoot = Split-Path $PSScriptRoot -Parent

# state.json mutlak deÄŸilse repo kÃ¶kÃ¼ne gÃ¶re Ã§Ã¶z
if ([IO.Path]::IsPathRooted($State)) { $statePath = $State } else { $statePath = Join-Path $repoRoot $State }

$outD  = Join-Path $repoRoot "_otokodlama\out"
New-Item -ItemType Directory -Force -Path $outD | Out-Null

$report = @{ ok=$true; items=@(); state=$statePath }

if (!(Test-Path $statePath)) {
  Write-Host "[VISUAL] no state.json, skipping -> $statePath"
  $report | ConvertTo-Json -Depth 5 | Set-Content "$outD\visual_report.json"
  exit 0
}

$state = Get-Content $statePath -Raw | ConvertFrom-Json
$steps = @($state.steps)

if ($null -eq $steps -or $steps.Count -eq 0) {
  Write-Host "[VISUAL] no steps in state.json"
  $report | ConvertTo-Json -Depth 5 | Set-Content "$outD\visual_report.json"
  exit 0
}

function Resolve-Rel([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  if ([IO.Path]::IsPathRooted($p)) { return $p }
  return (Join-Path $repoRoot $p)
}

$allOk = $true
foreach ($s in $steps) {
  $id  = $s.id
  $url = $s.url
  $vis = $s.visual

  $hasVis = ($null -ne $vis) -and ($vis.PSObject.Properties.Count -gt 0)
  if (-not $hasVis) {
    $report.items += @{ id=$id; url=$url; ok=$true; note="no visual config (skipped)" }
    continue
  }

  $base = Resolve-Rel $vis.baseline
  $curr = Resolve-Rel $vis.actual
  $thr  = 0.90
  if ($vis.threshold) { $thr = [double]$vis.threshold }

  if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($curr)) {
    $report.items += @{ id=$id; url=$url; ok=$false; error="visual.baseline/actual missing" }
    $allOk = $false
    continue
  }
  if (!(Test-Path $base)) {
    $report.items += @{ id=$id; url=$url; ok=$false; error="baseline not found: $base" }
    $allOk = $false
    continue
  }
  if (!(Test-Path $curr)) {
    $report.items += @{ id=$id; url=$url; ok=$false; error="actual not found: $curr" }
    $allOk = $false
    continue
  }

  $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "img_hash_compare.ps1") -A $base -B $curr
  $obj  = $json | ConvertFrom-Json
  $ok   = ([double]$obj.similarity -ge $thr)
  if (-not $ok) { $allOk = $false }

  $report.items += @{
    id=$id; url=$url; ok=$ok; similarity=$obj.similarity; threshold=$thr;
    baseline=$base; actual=$curr
  }
}

$report.ok = $allOk
$report | ConvertTo-Json -Depth 5 | Set-Content "$outD\visual_report.json"
if ($allOk) { Write-Host "[VISUAL] ALL PASSED"; exit 0 } else { Write-Warning "[VISUAL] SOME FAILED"; exit 1 }

