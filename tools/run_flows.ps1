param(
  [switch]$FailFast,
  [switch]$Soft
)
$ErrorActionPreference = "Stop"

$repo = Get-Location
$outD = Join-Path $repo "_otokodlama\out"
New-Item -ItemType Directory -Force -Path $outD | Out-Null

# ops/flows altÄ±ndaki tÃ¼m .flow dosyalarÄ±
$flows = Get-ChildItem "ops\flows\*.flow" -ErrorAction SilentlyContinue | % { $_.FullName }

if (-not $flows -or $flows.Count -eq 0) {
  Write-Host "[FLOWS] no .flow files found, skipping."
  # rapor boÅŸ da olsa yaz
  @{ ok=$true; flows=@() } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outD "flows_report.json") -Encoding utf8
  exit 0
}

$allOk = $true
$report = @{ ok = $true; flows = @() }

foreach ($flow in $flows) {
  $name = [IO.Path]::GetFileNameWithoutExtension($flow)
  $json = Join-Path $outD ($name + ".json")
  Write-Host "[FLOW] $flow"

  & python tools\pw_flow.py --steps $flow --out $json
  $rc = $LASTEXITCODE

  if (-not (Test-Path $json)) {
    Write-Warning "[FLOW] no json produced: $name (rc=$rc)"
    $allOk = $false
    $report.flows += @{ name=$name; ok=$false; error="no json"; first_error=$null; out=$null }
    if ($FailFast -and -not $Soft) { $report.ok=$false; $report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outD "flows_report.json") -Encoding utf8; exit 1 }
    continue
  }

  try {
    $j = Get-Content $json -Raw | ConvertFrom-Json
    $firstErr = $null
    if (-not $j.ok) {
      $allOk = $false
      $firstErr = @($j.results | Where-Object { -not $_.ok })[0]
      Write-Warning "[FLOW] FAILED: $name -> $($firstErr.cmd) $($firstErr.arg)"
    } else {
      Write-Host "[FLOW] PASSED: $name"
    }
    $report.flows += @{ name=$name; ok=$j.ok; first_error=$firstErr; out=$json }
  } catch {
    Write-Warning "[FLOW] invalid json: $name -> $($_.Exception.Message)"
    $allOk = $false
    $report.flows += @{ name=$name; ok=$false; error="invalid json"; first_error=$null; out=$json }
  }
}

$report.ok = $allOk
$report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outD "flows_report.json") -Encoding utf8

# Soft modda asla kÄ±rma, normal modda kÄ±r
if ($Soft) { exit 0 } else { if ($allOk) { exit 0 } else { exit 1 } }