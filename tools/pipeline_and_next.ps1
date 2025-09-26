# tools/pipeline_and_next.ps1
param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000,
  [string]$NextCard = ".\ops\next_ok_runcard.txt",
  [switch]$NoAccept,
  [switch]$DryRun,
  [switch]$SkipFlows
)
$ErrorActionPreference = "Stop"

$root    = Get-Location
$statusD = Join-Path $root "_otokodlama"
$serve   = Join-Path $PSScriptRoot "serve_then_pipeline.ps1"
$accept  = Join-Path $PSScriptRoot "accept_visual.ps1"
$runflows= Join-Path $PSScriptRoot "run_flows.ps1"
New-Item -ItemType Directory -Force -Path $statusD | Out-Null

# 1) PIPELINE (fail-safe)
$oldEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
try { $pipeOut = & powershell -ExecutionPolicy Bypass -File $serve -BindHost $BindHost -Port $Port 2>&1; $pipeExit=$LASTEXITCODE } finally { $ErrorActionPreference=$oldEap }
if ($null -eq $pipeExit) { $pipeExit = 1 }
$logPath = Join-Path $statusD "pipeline_last.log"
$pipeOut | Out-String | Set-Content $logPath -Encoding utf8

# 2) CONFIG
$auto = 0.98
try {
  $cfg = Get-Content (Join-Path $root "pipeline.config.json") -Raw | ConvertFrom-Json
  if ($cfg -and $cfg.acceptance) {
    if ($cfg.acceptance.auto_accept_if) { $auto = [double]$cfg.acceptance.auto_accept_if }
    elseif ($cfg.acceptance.screenshot_similarity) { $auto = [double]$cfg.acceptance.screenshot_similarity }
  }
} catch {}

# 3) LAYOUT REPORT veya PIPELINE Ã§Ä±ktÄ±sÄ±ndan parse
$repPath = Join-Path $root "layout_report.json"
$rep = $null
if (Test-Path $repPath) {
  try { $rep = Get-Content $repPath -Raw | ConvertFrom-Json } catch {}
}
if (-not $rep) {
  $txt = $pipeOut | Out-String
  if ($txt -imatch '\[LAYOUT\]\s*similarity\s*=\s*([0-9\.]+).*?improvements\s*=\s*(True|False).*?tests\s*=\s*(True|False)') {
    $rep = [pscustomobject]@{
      ok = $null
      similarity = [double]$Matches[1]
      improvements_ok = ($Matches[2] -eq 'True')
      tests_ok = ($Matches[3] -eq 'True')
      latest_screenshot = ($txt -imatch '\[SCREENSHOT\]\s*(\S+?\.png)') ? $Matches[1] : $null
      target = if ($cfg -and $cfg.target_screenshot) { $cfg.target_screenshot } else { 'targets\target.png' }
    }
  } else {
    throw "layout_report.json not found and similarity could not be parsed. See log: $logPath"
  }
}

# 4) FLOWS (ops/flows/*.flow) -> flows_ok
$flows_ok = $true
$flows_rc = $null
if (-not $SkipFlows -and (Test-Path $runflows)) {
  & powershell -ExecutionPolicy Bypass -File $runflows -FailFast
  $flows_rc = $LASTEXITCODE
  $flows_ok = ($flows_rc -eq 0)
}

# 5) PASS KARARI
$layout_ok = ($rep.similarity -ge $auto) -and ($rep.tests_ok -eq $true) -and ($rep.improvements_ok -eq $true)
$pass = $layout_ok -and $flows_ok

# 6) Baseline accept (opsiyonel)
if ($pass -and -not $NoAccept) {
  try { & powershell -ExecutionPolicy Bypass -File $accept | Out-Host } catch { Write-Warning "[ACCEPT] failed: $($_.Exception.Message)" }
}

# 7) STATUS JSON
[pscustomobject]@{
  when = (Get-Date).ToString("s")
  similarity = $rep.similarity
  threshold  = $auto
  layout_ok = $layout_ok
  flows_ok  = $flows_ok
  ok = $pass
  latest_screenshot = $rep.latest_screenshot
  target = $rep.target
  pipeline_exit = $pipeExit
  has_layout_json = (Test-Path $repPath)
  log = (Resolve-Path $logPath).Path
} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $statusD "status.json") -Encoding utf8

# 8) NEXT
if ($pass) {
  Write-Host "[NEXT] OK (layout>=$auto AND flows)."
  if (Test-Path $NextCard) {
    if ($DryRun) { Write-Host "[DRY] tools\apply_runcard.ps1 -Card $NextCard -NoConfirm" }
    else { & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "apply_runcard.ps1") -Card $NextCard -NoConfirm }
  } else {
    Write-Host "[NEXT] Runcard not found: $NextCard (skipped)"
  }
  exit 0
} else {
  Write-Warning "[NEXT] NOT satisfied. layout_ok=$layout_ok flows_ok=$flows_ok (sim=$([math]::Round($rep.similarity,4)) thr=$auto)"
  Write-Host  "See log: $logPath"
  exit 1
}
