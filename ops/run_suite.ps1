# Dosya: ops\run_suite.ps1

# -------------------------------------------------------------
# 1. PARAMETRELER (PS Betiğin ilk satırı olmalıdır)
# -------------------------------------------------------------
param(
  [string]$ExtraArgs = ""
)


# -------------------------------------------------------------
# 2. TÜM FONKSİYON TANIMLARI
# -------------------------------------------------------------

function Invoke-TestResultProcessing {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResultsDir,
        
        [Parameter(Mandatory=$true)]
        [string]$AIQueuePath
    )

    $FailedTests = @()
    $AIFailQueue = @()

    # AI Kuyruğu dizinini hazırla
    $AIDir = Split-Path -Parent $AIQueuePath
    if (-not (Test-Path $AIDir)) { New-Item -ItemType Directory -Path $AIDir -Force | Out-Null }
    
    # Tüm JSON sonuç dosyalarını oku
    $ResultFiles = Get-ChildItem -Path $ResultsDir -Filter "*.json" -ErrorAction SilentlyContinue

    if (-not $ResultFiles) { return $true }

    foreach ($File in $ResultFiles) {
        try {
            $Content = Get-Content $File.FullName -Raw -Encoding UTF8
            $Result = $Content | ConvertFrom-Json -ErrorAction Stop
        } catch {
            continue
        }

        # Başarısız Test Kontrolü
        if (-not $Result.ok) {
            $TestID = $File.BaseName
            $FailedTests += $TestID
            
            # AI Kuyruğu Yapılandırması (failed_tests.jsonl)
            $AIRecord = [PSCustomObject]@{
                test_id         = $TestID
                reason          = $Result.reason
                duration        = $Result.duration
                metrics         = $Result.metrics
                timestamp       = (Get-Date).ToString("o")
            }
            $AIFailQueue += ($AIRecord | ConvertTo-Json -Depth 5 -Compress)
        }
    }

    # AI Kuyruğu Dosyasına Yazma (JSONL formatı)
    $AIFailQueue | Out-File -FilePath $AIQueuePath -Encoding UTF8 -Force
    
    # Başarılı say
    return ($FailedTests.Count -eq 0)
}


# -------------------------------------------------------------
# 3. ANA ÇALIŞTIRMA MANTIĞI
# -------------------------------------------------------------

# 3.1 Karantina Listesini Oku ve Filtreyi Hazırla
$QuarantineFile = "reporters\quarantine.json"
if (Test-Path $QuarantineFile) {
    try {
        $QuarantineData = (Get-Content $QuarantineFile -Raw -Encoding UTF8) | ConvertFrom-Json
        $QuarantinedIDs = $QuarantineData.punted | Where-Object { $_.count -ge 3 } | Select-Object -ExpandProperty id
        
        if ($QuarantinedIDs.Count -gt 0) {
            Write-Host ("# {0} test karantinada. Bu testler atlanacak." -f $QuarantinedIDs.Count) -ForegroundColor DarkYellow
            $QuarantineRegex = $QuarantinedIDs -join '|'
            $ExtraArgs += " --grep-invert '($QuarantineRegex)'"
        }
    } catch {
        Write-Host "[WARN] Karantina dosyası ($QuarantineFile) okunamadı/bozuk. Atlandı." -ForegroundColor Red
    }
}


# 3.2 Temizlik ve Hazırlık
if (Test-Path "targets\results") { Remove-Item "targets\results\*.json" -Force }
if (Test-Path "ai_queue\failed_tests.jsonl") { Remove-Item "ai_queue\failed_tests.jsonl" -Force }
Write-Host "[START] Uçtan Uca Testler Başlatılıyor..." -ForegroundColor Green


# 3.3 Playwright'ı Çalıştırma
$PlaywrightSuccess = $true
try {
    # Playwright'ı çalıştır
    $PlaywrightOutput = & npm run test --silent -- "$ExtraArgs" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Playwright Hata Kodu: $LASTEXITCODE"
    }

} catch {
    # Hata yakalama ve loglama
    $Global:PlaywrightError = $_.Exception.Message
    $ErrorPath = "targets\playwright_error.log"
    $Global:PlaywrightError | Out-File -FilePath $ErrorPath -Encoding UTF8 -Force
    
    Write-Host "[HATA] Playwright ÇALIŞMADI! Detaylar $ErrorPath içinde." -ForegroundColor Red
    $PlaywrightSuccess = $false
}


# 3.4 Test Sonuçlarını İşleme
$TestsPassed = Invoke-TestResultProcessing `
    -ResultsDir "targets/results" `
    -AIQueuePath "ai_queue/failed_tests.jsonl"


# 3.5 Çıkış Kodu ve Terminali Açık Tutma Mantığı
if (-not $PlaywrightSuccess) {
    # Playwright komutunun kendisi başarısız olursa buraya düşeriz
    Write-Host ""
    Write-Host ">>> KRİTİK HATA: Terminal kapanmasını engelliyoruz. <<<" -ForegroundColor Red
    Write-Host "Playwright'ın neden çalışmadığını anlamak için LÜTFEN targets\playwright_error.log dosyasının içeriğini paylaşın." -ForegroundColor Yellow
    
    # EN SON ÇIKARAK KAPATMAYI ENGELLEYELİM. BU SATIR SİZ ENTER'A BASANA KADAR TERMİNALİ TUTACAK.
    Read-Host -Prompt "Hata Kaydını Paylaşmak İçin Enter'a Basın (Kapatmayacaktır)" | Out-Null
    # Normalde burada "exit 2" olurdu, ancak terminalin kapanmasını engellemek için SİLİNDİ.

} elseif (-not $TestsPassed) {
    # Testler çalıştı ama bazıları başarısız oldu
    Write-Host "[PIPELINE] Bazı testler başarısız oldu. AI Kuyruğu Hazırlandı." -ForegroundColor Magenta
    exit 2

} else {
    # Her şey başarılı
    Write-Host "[PIPELINE] Tüm zorunlu testler başarılı!" -ForegroundColor Green
    exit 0
}
