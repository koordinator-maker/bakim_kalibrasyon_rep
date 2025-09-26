param([switch]$FailFast)
$ErrorActionPreference = "Stop"

$repo = Get-Location
$outD = Join-Path $repo "_otokodlama\out"
New-Item -ItemType Directory -Force -Path $outD | Out-Null

$flows = @(
  "ops\flows\admin_home.flow",
  "ops\flows\admin_plan.flow",
  "ops\flows\admin_calibrations.flow",
  "ops\flows\admin_checklists.flow"
) | Where-Object { Test-Path $_ }

if ($flows.Count -eq 0) { Write-Host "[FLOWS] no .flow files found, skipping."; $flowsOk=$true } else {
  $flowsOk = $true
  foreach ($flow in $flows) {
    $name = [IO.Path]::GetFileNameWithoutExtension($flow)
    $json = Join-Path $outD ($name + ".json")
    Write-Host "[FLOW] $flow"
    & python tools\pw_flow.py --steps $flow --out $json
    $rc = $LASTEXITCODE
    if (-not (Test-Path $json)) {
      Write-Warning "[FLOW] no json produced: $name (rc=$rc)"; $flowsOk = $false; if ($FailFast) { exit 1 }; continue
    }
    try {
      $j = Get-Content $json -Raw | ConvertFrom-Json
      if (-not $j.ok) { Write-Warning "[FLOW] FAILED: $name"; $flowsOk = $false; if ($FailFast) { exit 1 } }
      else { Write-Host "[FLOW] PASSED: $name" }
    } catch {
      Write-Warning "[FLOW] invalid json: $name -> $($_.Exception.Message)"; $flowsOk = $false; if ($FailFast) { exit 1 }
    }
  }
  if ($flowsOk) { Write-Host "[FLOWS] ALL PASSED" } else { Write-Warning "[FLOWS] SOME FAILED" }
}

# --- Visual gate (ops/state.json) ---
$visualOk = $true
$vg = Join-Path $PSScriptRoot "visual_gate.ps1"
if (Test-Path $vg) {
  $statePath = Join-Path (Get-Location) "ops\state.json"
  if (Test-Path $statePath) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $vg -State $statePath
  } else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $vg
  }
  $visualOk = ($LASTEXITCODE -eq 0)
}


if ($visualOk) { Write-Host "[VISUAL] OK" } else { Write-Warning "[VISUAL] FAILED" }

if ($flowsOk -and $visualOk) { exit 0 } else { exit 1 }