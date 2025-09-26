param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000,
  [string]$NextCard = ".\ops\next_ok_runcard.txt",
  [switch]$NoAccept,
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"

$root    = Get-Location
$statusD = Join-Path $root "_otokodlama"
$serve   = Join-Path $PSScriptRoot "serve_then_pipeline.ps1"
$accept  = Join-Path $PSScriptRoot "accept_visual.ps1"
New-Item -ItemType Directory -Force -Path $statusD | Out-Null

# 1) Run pipeline (fail-safe) and capture output
$oldEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $pipeOut  = & powershell -ExecutionPolicy Bypass -File $serve -BindHost $BindHost -Port $Port 2>&1
  $pipeExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldEap
}
if ($null -eq $pipeExit) { $pipeExit = 1 }

$logPath = Join-Path $statusD "pipeline_last.log"
$pipeOut | Out-String | Set-Content $logPath -Encoding utf8

# 2) Load config (tolerant)
$cfgPath = Join-Path $root "pipeline.config.json"
$cfg = $null
try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json } catch { }

# Auto-accept threshold: acceptance.auto_accept_if -> acceptance.screenshot_similarity -> 0.98
$auto = 0.98
if ($cfg -and $cfg.acceptance) {
  if ($cfg.acceptance.auto_accept_if) {
    $auto = [double]$cfg.acceptance.auto_accept_if
  } elseif ($cfg.acceptance.screenshot_similarity) {
    $auto = [double]$cfg.acceptance.screenshot_similarity
  }
}

# 3) Read layout_report.json or parse from captured output
$repPath = Join-Path $root "layout_report.json"
$rep = $null
if (Test-Path $repPath) {
  try { $rep = Get-Content $repPath -Raw | ConvertFrom-Json } catch { $rep = $null }
}
if (-not $rep) {
  $txt = $pipeOut | Out-String

  # Example line:
  # [LAYOUT] similarity=0.8497 ok=False (shot>=0.9=False, improvements=True, tests=True)
  $similarity = $null
  $okTok = $null; $impr = $false; $tst = $false
  if ($txt -imatch '\[LAYOUT\]\s*similarity\s*=\s*([0-9\.]+)\s*ok\s*=\s*(True|False).*?improvements\s*=\s*(True|False).*?tests\s*=\s*(True|False)') {
    $similarity = [double]$Matches[1]
    $okTok = $Matches[2]
    $impr  = ($Matches[3] -eq 'True')
    $tst   = ($Matches[4] -eq 'True')
  }

  # Screenshot path (best-effort)
  $shot = $null
  if ($txt -imatch '\[SCREENSHOT\]\s*(\S+?\.png)') { $shot = $Matches[1] }

  # Target guess from config or default
  $target = if ($cfg -and $cfg.target_screenshot) { $cfg.target_screenshot } else { 'targets\target.png' }

  if ($similarity -ne $null) {
    $rep = [pscustomobject]@{
      ok = ($okTok -eq 'True')
      similarity = $similarity
      screenshot_ok = $null
      improvements_ok = $impr
      tests_ok = $tst
      latest_screenshot = $shot
      target = $target
    }
  } else {
    throw "layout_report.json not found and similarity could not be parsed. See log: $logPath"
  }
}

# 4) Decide pass
$pass = ($rep.similarity -ge $auto) -and ($rep.tests_ok -eq $true) -and ($rep.improvements_ok -eq $true)

# 5) Accept baseline if pass and not suppressed
if ($pass -and -not $NoAccept) {
  try {
    & powershell -ExecutionPolicy Bypass -File $accept | Out-Host
  } catch {
    Write-Warning "[ACCEPT] failed: $($_.Exception.Message)"
  }
}

# 6) Write status.json
[pscustomobject]@{
  when = (Get-Date).ToString("s")
  similarity = $rep.similarity
  threshold  = $auto
  ok = $pass
  latest_screenshot = $rep.latest_screenshot
  target = $rep.target
  pipeline_exit = $pipeExit
  has_layout_json = (Test-Path $repPath)
  log = (Resolve-Path $logPath).Path
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $statusD "status.json") -Encoding utf8

# 7) Next step
if ($pass) {
  Write-Host "[NEXT] condition satisfied (similarity=$([math]::Round($rep.similarity,4)) >= $auto)."
  if (Test-Path $NextCard) {
    if ($DryRun) {
      Write-Host "[DRY] tools\apply_runcard.ps1 -Card $NextCard -NoConfirm"
    } else {
      & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "apply_runcard.ps1") -Card $NextCard -NoConfirm
    }
  } else {
    Write-Host "[NEXT] Runcard not found: $NextCard (skipped)"
  }
  exit 0
} else {
  Write-Warning "[NEXT] NOT satisfied. similarity=$([math]::Round($rep.similarity,4)) threshold=$auto (tests=$($rep.tests_ok) improvements=$($rep.improvements_ok))"
  Write-Host  "See log: $logPath"
  exit 1
}