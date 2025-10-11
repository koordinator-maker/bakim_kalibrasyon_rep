param(
  [string]$Filter = "*",
  [string]$ExtraArgs = ""
)

$ErrorActionPreference = "Stop"
$flow_dir = ".\ops\flows"
$out_dir = ".\_otokodlama\out"

# Çıktı dizininin varlığını kontrol et
if (-not (Test-Path $out_dir)) {
    New-Item -ItemType Directory -Path $out_dir -Force | Out-Null
}

$files = Get-ChildItem -Path $flow_dir -Filter "$Filter.flow" -ErrorAction Stop

foreach ($file in $files) {
  $flow_file = $file.FullName
  $json_file = Join-Path $out_dir "$($file.BaseName).json"

  Write-Host "==> Running: $($file.Name)" -ForegroundColor Yellow

  # Sadece temel adımlar ve opsiyonel ExtraArgs. Timeout yok, BaseUrl yok.
  $python_command = "python tools\pw_flow.py --steps '$flow_file' --out '$json_file'"

  if ($ExtraArgs) {
    $python_command += " $ExtraArgs"
  }

  Write-Host "[run_and_guard] $($python_command)"

  try {
    # Doğrudan python çağrısı
    Invoke-Expression $python_command
    $exitCode = $LASTEXITCODE
  }
  catch {
    Write-Host "Python çağrısında hata: $_" -ForegroundColor Red
    $exitCode = 1
  }

  Write-Host "[guard] wrote: $($json_file)" -ForegroundColor Magenta
  if ($exitCode -ne 0) {
    Write-Host "[err] $($file.Name) exit=$exitCode" -ForegroundColor Red
  }
}
