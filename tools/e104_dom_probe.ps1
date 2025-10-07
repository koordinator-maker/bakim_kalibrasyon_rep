# Rev: 2025-10-06 11:42 r3 (debug logging)
[CmdletBinding()]
param(
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [switch]$Headed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Info($msg){ Write-Host "[info] $msg" -ForegroundColor Cyan }
function Warn($msg){ Write-Warning $msg }
function Fail($msg){ Write-Error $msg; exit 1 }

try {
  $repoRoot = git rev-parse --show-toplevel 2>$null
  if (-not $repoRoot) {
    $repoRoot = (Get-Location).Path
    Warn "Git kökü çözülemedi; mevcut klasör kullanılacak: $repoRoot"
  } else {
    Info "Repo kökü: $repoRoot"
  }
  Set-Location $repoRoot
} catch { Fail "Repo kökü ayarlanamadı: $($_.Exception.Message)" }

try {
  $toolsDir = Join-Path $repoRoot "tools"
  $outDir   = Join-Path $repoRoot "_otokodlama\out"
  $trDir    = Join-Path $repoRoot "test-results"
  New-Item -ItemType Directory -Force $toolsDir, $outDir, $trDir | Out-Null

  $env:BASE_URL   = $BaseUrl
  if (-not $env:ADMIN_USER) { $env:ADMIN_USER = "admin" }
  if (-not $env:ADMIN_PASS) { $env:ADMIN_PASS = "admin" }

  if ($PSBoundParameters.ContainsKey('Headed') -and $Headed.IsPresent) { $env:PW_HEADED = "1" } else { $env:PW_HEADED = "0" }
  Info "PW_HEADED=$env:PW_HEADED  BASE_URL=$env:BASE_URL"
} catch { Fail "Ortam hazırlığı başarısız: $($_.Exception.Message)" }

# 1) storage/user.json
try {
  $storageFile = Join-Path $repoRoot "storage\user.json"
  if (-not (Test-Path $storageFile)) {
    Info "storage yok -> npx playwright test --project setup"
    & npx playwright test --project setup --reporter list
    if ($LASTEXITCODE -ne 0) { Fail "Playwright setup projesi başarısız (exit $LASTEXITCODE)." }
    if (-not (Test-Path $storageFile)) { Fail "storage/user.json yine bulunamadı." }
  } else {
    Info "storage mevcut: $storageFile"
  }
} catch { Fail "storage hazırlığı hata: $($_.Exception.Message)" }

# 2) JS probe dosyasını garanti et
try {
  $jsPath = Join-Path $toolsDir "e104_dom_probe.js"
  if (-not (Test-Path $jsPath)) { Fail "JS probe eksik: $jsPath (önceki adım dosyayı yazmalıydı). Tekrar bootstrap çalıştır." }
  Info "JS probe: $jsPath"
} catch { Fail "JS dosya kontrolü hata: $($_.Exception.Message)" }

# 3) Node probe’u çalıştır
try {
  Info "node $jsPath (headed=$env:PW_HEADED)"
  $node = Start-Process -FilePath "node" -ArgumentList @("$jsPath") -NoNewWindow -Wait -PassThru
  if ($node.ExitCode -ne 0) { Fail "Node probe exit code: $($node.ExitCode)" }
} catch { Fail "Node çalıştırma hata: $($_.Exception.Message)" }

# 4) Özet
try {
  $reportPath = Join-Path $outDir "e104_dom_probe.json"
  if (-not (Test-Path $reportPath)) { Fail "Rapor bulunamadı: $reportPath" }
  $rep = Get-Content $reportPath -Raw | ConvertFrom-Json
  ""
  "=== E104 DOM PROBE ÖZET ==="
  "URL        : {0}" -f $rep.url_after_nav
  "Form Var mı: {0}" -f $rep.form_visible
  "Zorunlu    : text={0} number={1} date={2} select={3}" -f $rep.counts.text_like, $rep.counts.number, $rep.counts.date, $rep.counts.select
  "Buttons    : save={0} continue={1} submit-variants={2}" -f $rep.buttons.save, $rep.buttons.continue, $rep.buttons.submit_variants
  "Öneri-Name : {0}" -f (($rep.recommended_selectors.name_field_pref | Select-Object -First 3) -join " | ")
  "Kaydet Btn : {0}" -f $rep.recommended_selectors.save_button
  "DelConfirm : {0}" -f (($rep.recommended_selectors.delete_confirm_form) -join "  ||  ")
  "Artifacts  : html={0}  png={1}" -f $rep.artifacts.html, $rep.artifacts.screenshot
  ""
} catch { Fail "Özet üretimi hata: $($_.Exception.Message)" }