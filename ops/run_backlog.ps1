param(
  [string]$FlowsDir   = "ops\flows",
  [string]$OutDir     = "_otokodlama\out",
  [string]$ReportDir  = "_otokodlama\reports",
  [string[]]$Filter = @("*"),                # ör: "equipment_ui_*" veya "login_smoke*"
  [string]$ExtraArgs  = "",                 # pw_flow.py'ye geçer (örn: --timeout 20000)
  [switch]$LinkSmoke,                       # adım sonu link smoke gating
  [string]$BaseUrl    = "http://127.0.0.1:8010",
  [int]   $SmokeDepth = 1,
  [int]   $SmokeLimit = 150
)
$patterns = @($Filter)
Write-Host ("[run] Patterns: {0}" -f ($patterns -join ", ")) -ForegroundColor DarkGray
$files = @()
foreach($pat in $patterns){
  $files += Get-ChildItem -Path $FlowsDir -Filter ("{0}.flow" -f $pat) -ErrorAction SilentlyContinue
}
$flows = $files | Sort-Object FullName -Unique
if ($flows.Count -eq 0) {
  Write-Host ("[run] Akış bulunamadı. Aranan: {0}\{1}.flow" -f $FlowsDir, ($patterns -join ".flow, ")) -ForegroundColor Yellow
} else {
  Write-Host ("[run] Bulunan akış sayısı: {0}" -f $flows.Count) -ForegroundColor DarkGray
  Write-Host ("[run] Flows:`n - {0}" -f (($flows | ForEach-Object { $_.Name }) -join "`n - ")) -ForegroundColor DarkGray
}
Write-Host ("[run] Filter={0}" -f ($Filter -join ", ")) -ForegroundColor DarkGray
if (-not $OkRedirectTo) { $OkRedirectTo = "/_direct/.*|/admin/.*" }

New-Item -ItemType Directory -Force -Path $OutDir,$ReportDir | Out-Null

$patterns = @($Filter)
Write-Host ("[run] Patterns: {0}" -f ($patterns -join ", ")) -ForegroundColor DarkGray
$files = @()
foreach($pat in $patterns){
  $files += Get-ChildItem -Path $FlowsDir -Filter ("{0}.flow" -f $pat) -ErrorAction SilentlyContinue
}
$flows = $files | Sort-Object FullName -Unique
if ($flows.Count -eq 0) {
  Write-Host ("[run] Akış bulunamadı. Aranan: {0}\{1}" -f $FlowsDir, ($patterns -join ".flow, ")) -ForegroundColor Yellow
} else {
  Write-Host ("[run] Bulunan akış sayısı: {0}" -f $flows.Count) -ForegroundColor DarkGray
}
if ($flows.Count -eq 0) {
  exit 0
}

foreach ($f in $flows) {
  $out = Join-Path $OutDir ($f.BaseName + ".json")

  # Asıl flow'u çalıştır (guard'lı)
  powershell -ExecutionPolicy Bypass -File ops\run_and_guard.ps1 `
    -Steps $f.FullName `
    -Out   $out `
    -ExtraArgs $ExtraArgs

  # === Link Smoke Gating (adım sonunda) ===
  if ($LinkSmoke) {
    # backlog id: "equipment_ui_create" -> "equipment_ui"
    $idBase  = ($f.BaseName -replace '_(create|update|delete)$','')
    $backlog = Get-Content "ops\backlog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $item    = $backlog | Where-Object { $_.id -eq $idBase }

    if ($null -ne $item) {
      if ($item.type -eq "crud_admin") {
        $start  = $item.urls.list_direct
        # _direct olanlarda kök liste path'ini scope yap
        $prefix = ($start -replace '/_direct/.*$','/').TrimEnd('/') + '/'
      } else {
        $start  = $item.url
        $prefix = ($start.TrimEnd('/') + '/')
      }

      $smokeOutDir = "_otokodlama\smoke"
      New-Item -ItemType Directory -Force -Path $smokeOutDir | Out-Null
      $smokeOut = Join-Path $smokeOutDir ($f.BaseName + "_links.json")

      powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ops\_spawn.ps1 -File powershell -Args "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File","ops\smoke_links.ps1"  -OkRedirectTo "$OkRedirectTo" `
        -Base       $BaseUrl `
        -Start      $start `
        -Out        $smokeOut `
        -Depth      $SmokeDepth `
        -Limit      $SmokeLimit `
        -PathPrefix $prefix `
        -LoginPath  "/admin/login/" `
        -User       "admin" `
        -Pass       "Admin!2345" `
        -Timeout    20000

      if ($LASTEXITCODE -ne 0) {
        Write-Host "[run] Link smoke KIRMIZI → kalan akışlar durduruldu: $($f.BaseName)" -ForegroundColor Red
        break
      }
    }
  }
}

# Rapor (koşuya dair JSON'ları toparla)
$pattern = ($Filter -replace '\*','*') + ".json"
powershell -ExecutionPolicy Bypass -File ops\report_crud.ps1 `
  -OutDir   $OutDir `
  -ReportDir $ReportDir `
  -Include  $pattern

Write-Host "[run] Tamamlandı" -ForegroundColor Green




