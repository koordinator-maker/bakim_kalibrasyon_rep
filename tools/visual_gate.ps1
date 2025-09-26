param([string]$State="ops\state.json")
$ErrorActionPreference="Stop"

$repo  = Get-Location
$outD  = "_otokodlama\out"
New-Item -ItemType Directory -Force -Path $outD | Out-Null

$report = @{ ok=$true; items=@() }

if (!(Test-Path $State)) {
  Write-Host "[VISUAL] no state.json, skipping"
  $report | ConvertTo-Json | Set-Content "$outD\visual_report.json"
  exit 0
}

$state = Get-Content $State -Raw | ConvertFrom-Json
$steps = @($state.steps)

if ($null -eq $steps -or $steps.Count -eq 0) {
  Write-Host "[VISUAL] no steps in state.json"
  $report | ConvertTo-Json | Set-Content "$outD\visual_report.json"
  exit 0
}

$allOk = $true
foreach ($s in $steps) {
  $id   = $s.id
  $url  = $s.url
  $vis  = $s.visual

  if (-not $vis) {
    $report.items += @{ id=$id; url=$url; ok=$true; note="no visual config (skipped)" }
    continue
  }

  # Yolları repo köküne göre çöz
  function R([string]$p) { if ([string]::IsNullOrWhiteSpace($p)) { return $null } else { return (Join-Path $repo $p) } }

  $base = R $vis.baseline
  $curr = R $vis.actual
  $thr  = if ($vis.threshold) { [double]$vis.threshold } else { 0.90 }

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
  $rc = $LASTEXITCODE
  $obj = $json | ConvertFrom-Json
  $ok  = ($obj.similarity -ge $thr)
  if (-not $ok) { $allOk = $false }

  $report.items += @{
    id=$id; url=$url; ok=$ok; similarity=$obj.similarity; threshold=$thr;
    baseline=$base; actual=$curr
  }
}

$report.ok = $allOk
$report | ConvertTo-Json -Depth 5 | Set-Content "$outD\visual_report.json"
if ($allOk) { Write-Host "[VISUAL] ALL PASSED"; exit 0 } else { Write-Warning "[VISUAL] SOME FAILED"; exit 1 }