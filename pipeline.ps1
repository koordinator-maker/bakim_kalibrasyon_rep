# REV: 1.0 | 2025-09-25 | Hash: TBD | Parça: 1/1
Param(
  [string]$Settings = "core.settings"
)
$ErrorActionPreference = "Stop"

# -------------------- Ortam & Yol Kurulumu --------------------
$Root = (Get-Location).Path
$Ts   = Get-Date -Format "yyyyMMdd-HHmmss"
$OutDir = Join-Path $Root ("_otokodlama/out/" + $Ts)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Tam terminal dökümü
Start-Transcript -Path (Join-Path $OutDir "transcript.txt") -Force | Out-Null

# Config yükle
$ConfigPath = Join-Path $Root "pipeline.config.json"
if (Test-Path $ConfigPath) {
  $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} else {
  throw "pipeline.config.json bulunamadı."
}

# -------------------- Yardımcılar --------------------
function Step($name, $scriptBlock) {
  Write-Host "==> $name"
  try {
    & $scriptBlock 2>&1 | Tee-Object -FilePath (Join-Path $OutDir ("$($name -replace '\s','_').log"))
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) { throw "$name exit code $LASTEXITCODE" }
  } catch {
    Write-Host "!  $name FAILED"
    Stop-Transcript | Out-Null
    throw
  }
}

function StepSoft($name, $scriptBlock) {
  Write-Host "==> $name (soft)"
  try {
    & $scriptBlock 2>&1 | Tee-Object -FilePath (Join-Path $OutDir ("$($name -replace '\s','_').log"))
  } catch {
    Write-Host "!  $name FAILED (soft, continuing)"
  }
}

# 650 satır üstü gate (venv, node_modules, _otokodlama hariç)
function Gate-LineLimit650 {
  $limit = 650
  $long = @()
  Get-ChildItem -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\venv\\' -and
    $_.FullName -notmatch '\\node_modules\\' -and
    $_.FullName -notmatch '\\_otokodlama\\' -and
    $_.Name -ne "transcript.txt"
  } | ForEach-Object {
    try {
      $cnt = [System.IO.File]::ReadLines($_.FullName).Count
      if ($cnt -gt $limit) {
        $long += "{0} : {1} satır" -f ($_).FullName, $cnt
      }
    } catch { }
  }
  $out = Join-Path $OutDir "longfiles.txt"
  $long | Out-File -Encoding utf8 $out
  if ($long.Count -gt 0) {
    Write-Host "[LONGFILES] 650+ satır bulundu, detay için: $out"
    throw "650 satır sınırı aşıldı."
  } else {
    Write-Host "[LONGFILES] OK (650 üstü yok)"
  }
}

# -------------------- Adımlar --------------------
# (İstersen aktif tut: revstamp / blockcheck / guardrail)
#Step "revstamp" { python tools/revstamp.py . }
Step "blockcheck" { python tools/blockcheck.py --tracked }
Step "guardrail_check" { python tools/guardrail_check.py }

# 650 satır gate
Step "line_limit_650" { Gate-LineLimit650 }

# Django check (soft)
StepSoft "django_check" { .\scripts\django_check.ps1 -Settings $Settings -Soft }

# Ekran görüntüsü (her koşuda)
$ScreensDir = Join-Path $Root $Config.screenshots_dir
Step "screenshot" {
  .\scripts\capture_screenshot.ps1 -OutDir $ScreensDir -AlsoCopyTo $OutDir
}

# Playwright testleri
$PwOut = Join-Path $OutDir "playwright"
Step "playwright" {
  if (!(Test-Path $PwOut)) { New-Item -ItemType Directory -Force -Path $PwOut | Out-Null }
  python tools/playwright_tests.py --urls $Config.urls_file --out $PwOut
}

# Layout acceptance (hedef ekran + iyileştirme + test sonucu)
$TargetPng = Join-Path $Root $Config.target_screenshot
$ImproveTx = Join-Path $Root $Config.improvements_file
$LayJson   = Join-Path $OutDir "layout_report.json"
$PwJson    = Join-Path $PwOut "report.json"
$Th        = [double]$Config.acceptance.screenshot_similarity

Step "acceptance_gate" {
  python tools/layout_acceptance.py `
    --target $TargetPng `
    --latest $ScreensDir `
    --improve $ImproveTx `
    --report $LayJson `
    --threshold $Th `
    --playwright_json $PwJson
}

Write-Host "[PIPELINE] Tamamlandı."
Stop-Transcript | Out-Null
