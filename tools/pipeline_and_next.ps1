param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000,
  [string]$NextCard = ".\ops\next_ok_runcard.txt",
  [switch]$NoAccept,
  [switch]$DryRun,
  [switch]$SkipFlows
, [switch]$NonBlocking)
$ErrorActionPreference = "Stop"

$root    = Get-Location
$statusD = Join-Path $root "_otokodlama"
$serve   = Join-Path $PSScriptRoot "serve_then_pipeline.ps1"
$accept  = Join-Path $PSScriptRoot "accept_visual.ps1"
$runflows= Join-Path $PSScriptRoot "run_flows.ps1"
New-Item -ItemType Directory -Force -Path $statusD | Out-Null

# 1) Pipeline (fail-safe) ve Ã§Ä±ktÄ±yÄ± yakala
$oldEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $pipeOut  = & powershell -NoProfile -ExecutionPolicy Bypass -File $serve -BindHost $BindHost -Port $Port 2>&1
  $pipeExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldEap
}
if ($null -eq $pipeExit) { $pipeExit = 1 }
$logPath = Join-Path $statusD "pipeline_last.log"
$pipeOut | Out-String | Set-Content $logPath -Encoding utf8

# 2) Config oku
$auto = 0.98
try {
  $cfg = Get-Content (Join-Path $root "pipeline.config.json") -Raw | ConvertFrom-Json
  if ($cfg -and $cfg.acceptance) {
    if ($cfg.acceptance.auto_accept_if) {
      $auto = [double]$cfg.acceptance.auto_accept_if
    } elseif ($cfg.acceptance.screenshot_similarity) {
      $auto = [double]$cfg.acceptance.screenshot_similarity
    }
  }
} catch {}

# 3) Rapor: layout_report.json varsa onu kullan; yoksa stdoutâ€™tan parse et
$repPath = Join-Path $root "layout_report.json"
$rep = $null
if (Test-Path $repPath) {
  try { $rep = Get-Content $repPath -Raw | ConvertFrom-Json } catch {}
}
if (-not $rep) {
  $txt = $pipeOut | Out-String
  $sim  = $null
  $impr = $false
  $tst  = $false
  if ($txt -imatch '\[LAYOUT\]\s*similarity\s*=\s*([0-9\.]+).*?improvements\s*=\s*(True|False).*?tests\s*=\s*(True|False)') {
    $sim  = [double]$Matches[1]
    $impr = ($Matches[2] -eq 'True')
    $tst  = ($Matches[3] -eq 'True')
  } else {
    throw "layout_report.json not found and similarity could not be parsed. See log: $logPath"
  }
  $latestShot = $null
  if ($txt -imatch '\[SCREENSHOT\]\s*(\S+?\.png)') { $latestShot = $Matches[1] }

  $target = 'targets\target.png'
  if ($cfg -and $cfg.target_screenshot) { $target = $cfg.target_screenshot }

  $rep = [pscustomobject]@{
    ok = $null
    similarity = $sim
    improvements_ok = $impr
    tests_ok = $tst
    latest_screenshot = $latestShot
    target = $target
  }
}

# 4) Flows gate (opsiyonel)
$flows_ok = $true
$flows_rc = $null
if (-not $SkipFlows -and (Test-Path $runflows)) {
  if ($NonBlocking) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runflows -Soft
  } else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runflows -FailFast
  }
  $flows_rc = $LASTEXITCODE
  $flows_ok = ($NonBlocking) -or ($flows_rc -eq 0)
}

# 5) PASS kararÄ±
$layout_ok = ($rep.similarity -ge $auto) -and ($rep.tests_ok -eq $true) -and ($rep.improvements_ok -eq $true)
$pass = $layout_ok -and $flows_ok

# 6) Baseline accept (isteÄŸe baÄŸlÄ±)
if ($pass -and -not $NoAccept) {
  try { & powershell -NoProfile -ExecutionPolicy Bypass -File $accept | Out-Host } catch { Write-Warning "[ACCEPT] failed: $($_.Exception.Message)" }
}

# 7) status.json
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
    if ($DryRun) {
      Write-Host "[DRY] tools\apply_runcard.ps1 -Card $NextCard -NoConfirm"
    } else {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "apply_runcard.ps1") -Card $NextCard -NoConfirm
    }
  } else {
    Write-Host "[NEXT] Runcard not found: $NextCard (skipped)"
  }
  exit 0
} else {
  Write-Warning "[NEXT] NOT satisfied. layout_ok=$layout_ok flows_ok=$flows_ok (sim=$([math]::Round($rep.similarity,4)) thr=$auto)"
  Write-Host  "See log: $logPath"
  exit 1
}



