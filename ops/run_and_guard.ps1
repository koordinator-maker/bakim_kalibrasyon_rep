param(
  [Parameter(Mandatory=$true)][string]$flow,         # .flow dosyasının tam yolu
  [Parameter(Mandatory=$true)][string]$outPath,      # JSON çıktı yolu
  [string]$BaseUrl = "http://127.0.0.1:8010",        # BASE_URL env
  [string]$ExtraArgs = ""                            # pw_flow.py'ye ham argümanlar ("--timeout 5000" gibi)
)

$ErrorActionPreference = "Stop"

# Ortam değişkenleri
$env:BASE_URL = $BaseUrl
$env:PYTHONUNBUFFERED = "1"

# Çıktı klasörünü garanti et
$op = Split-Path -Parent $outPath
if ($op -and -not (Test-Path $op)) { New-Item -ItemType Directory -Force -Path $op | Out-Null }

# Extra argümanları güvenli diziye çevir
$ea = @()
if ($ExtraArgs) {
  # whitespace'e göre böl (ör: "--timeout 5000")
  $ea = $ExtraArgs -split '\s+'
}

# Python çağrısı (doğrudan, güvenli)
Write-Host ("[run_and_guard] python tools\pw_flow.py --steps {0} --out {1} {2}" -f $flow, $outPath, ($ea -join " "))
& python -u "tools\pw_flow.py" --steps $flow --out $outPath @ea
$exitCode = $LASTEXITCODE

# Guard tarzı bilgi satırı (izleme kolaylığı için)
if (Test-Path $outPath) { Write-Host "[guard] wrote: $outPath" }

exit $exitCode

