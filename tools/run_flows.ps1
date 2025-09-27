param(
  [switch]$FailFast,
  [switch]$Soft
)
$ErrorActionPreference = "Stop"

$repo = Get-Location
$outD = Join-Path $repo "_otokodlama\out"
New-Item -ItemType Directory -Force -Path $outD | Out-Null

# Koşturulacak flow listesi
$flows = @(
  "ops\flows\admin_home.flow",
  "ops\flows\admin_plan.flow",
  "ops\flows\admin_calibrations.flow",
  "ops\flows\admin_checklists.flow",
  "ops\flows\admin_equipment.flow"   # <-- eklendi
) | Where-Object { Test-Path $_ }

$results = @()
$anyFail = $false

foreach ($flow in $flows) {
  $name = [IO.Path]::GetFileName($flow)
  $stem = [IO.Path]::GetFileNameWithoutExtension($flow)
  $json = Join-Path $outD ($stem + ".json")

  Write-Host "[FLOW] $flow"
  & python tools\pw_flow.py --steps $flow --out $json
  $rc = $LASTEXITCODE

  $ok = $false
  $firstErr = $null
  if (Test-Path $json) {
    try {
      $j = Get-Content $json -Raw | ConvertFrom-Json
      $ok = [bool]$j.ok
      if (-not $ok -and $j.results) {
        $firstErr = ($j.results | Where-Object { -not $_.ok } | Select-Object -First 1)
      }
    } catch {
      $ok = $false
      $firstErr = @{ cmd="PARSE_JSON"; arg=$json; url=""; error=$_.Exception.Message }
    }
  } else {
    $ok = $false
    $firstErr = @{ cmd="NO_JSON"; arg=$json; url=""; error="json üretilmedi (rc=$rc)" }
  }

  if ($ok) {
    Write-Host "[FLOW] PASSED: $stem"
  } else {
    Write-Warning "[FLOW] FAILED: $stem"
    $anyFail = $true
    if ($FailFast -and -not $Soft) { break }
  }

  $results += [pscustomobject]@{
    name = $stem
    flow = $name
    ok   = $ok
    out  = ".\_otokodlama\out\$($stem).json"
    first_error = $firstErr
  }
}

# flows_report.json: { "flows": [...] } şeklinde yaz
@{ flows = $results } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outD "flows_report.json") -Encoding utf8

if ($Soft) {
  # Non-blocking modda her zaman 0 ile çık
  exit 0
} else {
  if ($anyFail) { exit 1 } else { exit 0 }
}