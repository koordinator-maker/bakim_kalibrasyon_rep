param(
  [string]$FlowsDir  = "ops\flows",
  [string]$OutDir    = "_otokodlama\out",
  [string]$ReportDir = "_otokodlama\reports",
  [string]$Filter    = "*"  # ör: "equipment_ui_*" veya "login_smoke*"
)

New-Item -ItemType Directory -Force -Path $OutDir,$ReportDir | Out-Null

$flows = Get-ChildItem $FlowsDir -Filter "$Filter.flow" -ErrorAction SilentlyContinue | Sort-Object Name
if ($flows.Count -eq 0) {
  Write-Host "[run] Akış bulunamadı: $FlowsDir\$Filter.flow" -ForegroundColor Yellow
  exit 0
}

# İlgili CRUD item'ları için isteğe bağlı cleanup/ensure tetikleyici (kolaylaştırma)
# (Basit mantık: create yoksa ensure; delete öncesi ensure vs. Gerekirse senaryo bazlı genişletilir.)

foreach ($f in $flows) {
  $out = Join-Path $OutDir ($f.BaseName + ".json")
  powershell -ExecutionPolicy Bypass -File ops\run_and_guard.ps1 `
    -Steps $f.FullName `
    -Out   $out
}

# Rapor
$pattern = ($Filter -replace '\*','*') + ".json"
powershell -ExecutionPolicy Bypass -File ops\report_crud.ps1 `
  -OutDir   $OutDir `
  -ReportDir $ReportDir `
  -Include  $pattern

Write-Host "[run] Tamamlandı" -ForegroundColor Green
