param(
  [string[]]$Filter = @("*"),         # Birden çok desen destekli: "login_smoke*","equipment_ui_*"
  [switch]$LinkSmoke,                 # Link smoke gate çalışsın mı?
  [string]$BaseUrl    = "http://127.0.0.1:8010",
  [int]   $SmokeDepth = 1,
  [int]   $SmokeLimit = 150,
  [string]$ExtraArgs  = ""            # pw_flow.py'ye geçer, ör: "--timeout 5000"
)

# --- Yardımcılar ---
$ErrorActionPreference = "Stop"
$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = $here                        # projenizde ops klasörü kök dizinde ise bu yeterli
$FlowsDir = Join-Path $here 'flows'

# Filter normalize
if ($Filter -is [string]) { $Filter = @($Filter) }
Write-Host ("[run] Filters: {0}" -f ($Filter -join ", "))

# Akışları topla (çoklu pattern)
$files = @()
foreach($pat in $Filter){
  if ([string]::IsNullOrWhiteSpace($pat)) { continue }
  $files += Get-ChildItem -Path $FlowsDir -Filter ("{0}.flow" -f $pat) -ErrorAction SilentlyContinue
}
$flows = $files | Sort-Object FullName -Unique
if ($flows.Count -eq 0) {
  Write-Host "[run] Akış bulunamadı." -ForegroundColor Yellow
  return
}
Write-Host ("[run] Bulunan akış sayısı: {0}" -f $flows.Count)
Write-Host ("[run] Flows:`n - {0}" -f (($flows | ForEach-Object { $_.Name }) -join "`n - "))

# Ortam: unbuffered python
$env:PYTHONUNBUFFERED = "1"

# Çıktı klasörleri
$outDir   = "_otokodlama\out"
$smkDir   = "_otokodlama\smoke"
$repDir   = "_otokodlama\reports"
New-Item -ItemType Directory -Force -Path $outDir,$smkDir,$repDir | Out-Null

# OkRedirectTo default
if (-not $OkRedirectTo) { $OkRedirectTo = "/_direct/.*|/admin/.*" }

# --- Ana döngü ---
foreach ($f in $flows) {
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $outPath  = Join-Path $repoRoot (Join-Path $outDir  ("{0}.json" -f $baseName))
  $smkOut   = $outPath  # link-smoke çıktısını da aynı dosyaya yazıyoruz (mevcut işleyişle uyumlu)
  $startTs  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")

  Write-Host ("[run] >>> {0}" -f $baseName) -ForegroundColor Cyan

  # 1) Akışı çalıştır (ops\run_and_guard.ps1 mevcut davranışı korur)
  powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $here "run_and_guard.ps1") `
    -flow $f.FullName `
    -outPath $outPath `
    -BaseUrl $BaseUrl `
    -ExtraArgs $ExtraArgs

  # 2) İsteğe bağlı link smoke (DIŞARIDA -Out AMBIGUOUS YOK; doğrudan fonksiyon çağrısı)
  if ($LinkSmoke) {
    Write-Host "[run] Link smoke kontrolü başlıyor..." -ForegroundColor DarkGray
    & (Join-Path $here "smoke_links.ps1") `
      -Base        $BaseUrl `
      -Start       $startTs `
      -Out         $smkOut `
      -Depth       $SmokeDepth `
      -Limit       $SmokeLimit `
      -PathPrefix  "/" `
      -Timeout     5000 `
      -OkRedirectTo $OkRedirectTo
  }

  Write-Host ("[run] <<< {0} tamam" -f $baseName) -ForegroundColor Green
}

# 3) Özet raporu isteğe bağlı (bozuk parametre geliyordu; burada dokunmuyoruz)
Write-Host "[run] Tamamlandı"
