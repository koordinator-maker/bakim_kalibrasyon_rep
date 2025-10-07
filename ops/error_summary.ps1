param(
    [string]$OutDir = "_otokodlama\out"
)

$ErrorActionPreference = "Continue"

Write-Host "
--- HATA ÖZETİ BAŞLADI ---" -ForegroundColor Cyan

$errorCount = 0
$files = Get-ChildItem -Path $OutDir -Filter "*.json" -ErrorAction SilentlyContinue

if (-not $files) {
    Write-Host "[WARN] $OutDir altında JSON dosya bulunamadı." -ForegroundColor Yellow
    exit 0
}

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    # 1. JSON'u parse etmeyi dene (hata yoksa)
    try {
        $data = $content | ConvertFrom-Json -ErrorAction Stop
        if ($data -and $data.error) {
            Write-Host "FAIL : " -ForegroundColor Red
            $errorCount++
        } elseif ($data -and $data.status -eq "PASS") {
            # Hata yok, başarılı
        } else {
            # Beklenmedik durum (boş JSON veya status yok)
            Write-Host "UNKNOW : Beklenmedik JSON formatı veya boş çıktı." -ForegroundColor DarkYellow
            $errorCount++
        }
    }
    # 2. JSON parse edilemezse (bozuk JSON, muhtemelen bir kilitlenme sonucu)
    catch {
        # Ham metin içinde hatayı ara (Playwright/Node hata metni)
        $match = [regex]::Match($content, "Error: ([^
]+)")
        if ($match.Success) {
            Write-Host "CRITICAL : [HAM HATA] " -ForegroundColor Magenta
            $errorCount++
        } else {
            # Çok nadir: JSON bozuk ama ham hata da bulunamadı
            Write-Host "CRITICAL : [HAM OKUNAMADI] JSON bozuk, kök hata bulunamadı." -ForegroundColor DarkRed
            $errorCount++
        }
    }
}

Write-Host "--- HATA ÖZETİ BİTTİ. Toplam Hata: $errorCount ---" -ForegroundColor Cyan

if ($errorCount -gt 0) {
    exit 2 # Kırmızı çıkış kodu
}
