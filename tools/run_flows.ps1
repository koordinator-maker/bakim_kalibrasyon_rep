param(
  [switch]$FailFast
)
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

if ($flows.Count -eq 0) {
  Write-Host "[FLOWS] no .flow files found, skipping."
  exit 0
}

$allOk = $true
foreach ($flow in $flows) {
  $name = [IO.Path]::GetFileNameWithoutExtension($flow)
  $json = Join-Path $outD ($name + ".json")
  Write-Host "[FLOW] $flow"
  & python tools\pw_flow.py --steps $flow --out $json
  $rc = $LASTEXITCODE
  if (-not (Test-Path $json)) {
    Write-Warning "[FLOW] no json produced: $name (rc=$rc)"
    $allOk = $false
    if ($FailFast) { exit 1 }
    continue
  }
  try {
    $j = Get-Content $json -Raw | ConvertFrom-Json
    if (-not $j.ok) {
      Write-Warning "[FLOW] FAILED: $name"
      $allOk = $false
      if ($FailFast) { exit 1 }
    } else {
      Write-Host "[FLOW] PASSED: $name"
    }
  } catch {
    Write-Warning "[FLOW] invalid json: $name -> $($_.Exception.Message)"
    $allOk = $false
    if ($FailFast) { exit 1 }
  }
}

if ($allOk) {
  Write-Host "[FLOWS] ALL PASSED"
  exit 0
} else {
  Write-Warning "[FLOWS] SOME FAILED"
  exit 1
}