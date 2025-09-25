param(
  [string]$BindHost="127.0.0.1",
  [int]$Port=8000,
  [string]$NextCard = ".\ops\next_ok_runcard.txt",
  [switch]$NoAccept,
  [switch]$DryRun
)
$ErrorActionPreference="Stop"

$root    = Get-Location
$serve   = Join-Path $PSScriptRoot 'serve_then_pipeline.ps1'
$accept  = Join-Path $PSScriptRoot 'accept_visual.ps1'
$statusD = Join-Path $root '_otokodlama'
New-Item -ItemType Directory -Force -Path $statusD | Out-Null

# 1) Pipeline’ı ÇALIŞTIR + ÇIKTISINI YAKALA
$pipeOut = & powershell -ExecutionPolicy Bypass -File $serve -BindHost $BindHost -Port $Port 2>&1
$pipeExit = $LASTEXITCODE
$logPath = Join-Path $statusD 'pipeline_last.log'
$pipeOut | Out-String | Set-Content $logPath -Encoding utf8

# 2) Config yükle
$cfgPath = Join-Path $root 'pipeline.config.json'
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

# Auto-accept eşiği: yoksa screenshot_similarity, o da yoksa 0.98
$auto = 0.98
if ($cfg.acceptance) {
  if ($cfg.acceptance.auto_accept_if) {
    $auto = [double]$cfg.acceptance.auto_accept_if
  } elseif ($cfg.acceptance.screenshot_similarity) {
    $auto = [double]$cfg.acceptance.screenshot_similarity
  }
}

# 3) Raporu oku; yoksa ÇIKTIDAN PARSE ET (fallback)
$repPath = Join-Path $root 'layout_report.json'
$rep = $null
if (Test-Path $repPath) {
  $rep = Get-Content $repPath -Raw | ConvertFrom-Json
} else {
  # Fallback: [LAYOUT] similarity=0.8497 ok=False (shot>=0.9=False, improvements=True, tests=True)
  $txt = $pipeOut | Out-String

  $similarity = $null
  $okTok = $null
  $impr = $null
  $tst  = $null
  $shot = $null
  $target = $null

  if ($txt -match '\[LAYOUT\]\s*similarity=([0-9.]+)\s*ok=(True|False)\s*\((?:[^)]*?)improvements=(True|False),\s*tests=(True|False)\)') {
    $similarity = [double]$Matches[1]
    $okTok      = $Matches[2]
    $impr       = ($Matches[3] -eq 'True')
    $tst        = ($Matches[4] -eq 'True')
  }
  # [SCREENSHOT] C:\...\screenshot-YYYYMMDD-HHMMSS.png
  if ($txt -match '\[SCREENSHOT\]\s*(\S+\.png)') { $shot = $Matches[1] }

  # hedefi tahmin et (config’ten)
  if ($cfg.target_screenshot) {
    $target = $cfg.target_screenshot
  } else {
    $target = 'targets\target.png'
  }

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
    throw "layout_report.json yok ve pipeline çıktısından similarity parse edilemedi. Log: $logPath"
  }
}

# 4) Geçti mi?
$pass = ($rep.similarity -ge $auto) -and ($rep.tests_ok -eq $true) -and ($rep.improvements_ok -eq $true)

# 5) Geçtiyse baseline kabul et (isteğe bağlı)
if ($pass -and -not $NoAccept) {
  & powershell -ExecutionPolicy Bypass -File $accept | Out-Host
}

# 6) Durum yaz
[pscustomobject]@{
  when = (Get-Date).ToString("s")
  similarity = $rep.similarity
  threshold  = $auto
  ok = $pass
  latest_screenshot = $rep.latest_screenshot
  target = $rep.target
  pipeline_exit = $pipeExit
  has_layout_json = (Test-Path $repPath)
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $statusD 'status.json') -Encoding utf8

# 7) Sonraki adım
if ($pass) {
  Write-Host "[NEXT] condition satisfied (similarity=$($rep.similarity) >= $auto)."
  if (Test-Path $NextCard) {
    if ($DryRun) {
      Write-Host "[DRY] tools\\apply_runcard.ps1 -Card $NextCard -NoConfirm"
    } else {
      & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply_runcard.ps1') -Card $NextCard -NoConfirm
    }
  } else {
    Write-Host "[NEXT] Runcard not found: $NextCard (skipped)"
  }
  exit 0
} else {
  Write-Warning "[NEXT] NOT satisfied. similarity=$([math]::Round($rep.similarity,4)) threshold=$auto (tests=$($rep.tests_ok) improvements=$($rep.improvements_ok))"
  Write-Host "See log: $logPath"
  exit 1
}