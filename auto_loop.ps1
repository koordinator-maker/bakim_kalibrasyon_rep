# === auto_loop.ps1 - Tam Otomatik AI Döngüsü ===
<#
.SYNOPSIS
    Görev seçimi → Test → Rapor → AI patch → Uygula → Yeniden test → Güncelle
.PARAMETER MaxRounds
    Maksimum tur sayısı (default: 3)
.PARAMETER TaskId
    Belirli bir görev ID'si (null ise CSV'den ilk todo seçilir)
.PARAMETER Mode
    AI bridge modu: direct (HTTP) | github (PR) | local (manuel)
.EXAMPLE
    .\auto_loop.ps1 -MaxRounds 3 -Mode direct
#>
param(
    [int]$MaxRounds = 3,
    [string]$TaskId = $null,
    [ValidateSet('direct','github','local')]
    [string]$Mode = 'direct'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Hataları logla ama devam et

$loopStartTime = Get-Date
$loopLogPath = "_otokodlama\logs\auto_loop_$(Get-Date -Format yyyyMMddHHmmss).txt"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    # Konsol
    $color = switch($Level){
        'ERROR' {'Red'}
        'WARN' {'Yellow'}
        'SUCCESS' {'Green'}
        default {'White'}
    }
    Write-Host $logLine -ForegroundColor $color
    
    # Dosya
    Add-Content -Path $loopLogPath -Value $logLine -Encoding UTF8
}

Write-Log "========================================" "INFO"
Write-Log "AUTO LOOP BAŞLIYOR" "INFO"
Write-Log "MaxRounds: $MaxRounds | Mode: $Mode" "INFO"
Write-Log "========================================" "INFO"

# ============================================================================
# 0. HAZIRLIK
# ============================================================================

Write-Log "[0/9] HAZIRLIK" "INFO"

# 0.1. Dizinleri kontrol et
$requiredDirs = @(
    '_otokodlama\out',
    '_otokodlama\inbox',
    '_otokodlama\logs',
    '_otokodlama\reports',
    '_otokodlama\bundle',
    'build',
    'dashboard'
)

foreach($dir in $requiredDirs){
    if(!(Test-Path $dir)){
        New-Item -ItemType Directory -Force $dir | Out-Null
        Write-Log "Dizin olusturuldu: $dir" "INFO"
    }
}

# 0.2. ENV yükle
if(Test-Path load_env.ps1){
    . .\load_env.ps1
    Write-Log "ENV yuklendi (.env)" "SUCCESS"
} else {
    Write-Log "load_env.ps1 yok - manuel ENV gerekli" "WARN"
}

# 0.3. Quarantine modülünü yükle
if(Test-Path ops\quarantine.ps1){
    . .\ops\quarantine.ps1
    Write-Log "Quarantine modulu yuklendi" "SUCCESS"
} else {
    Write-Log "ops\quarantine.ps1 yok!" "ERROR"
}

# ============================================================================
# 1. GÖREV SEÇİMİ (CSV → tasks.json → ilk todo)
# ============================================================================

Write-Log "[1/9] GOREV SECIMI" "INFO"

# 1.1. CSV'den JSON oluştur
if(Test-Path ops\csv_to_tasks.ps1){
    & .\ops\csv_to_tasks.ps1
    Write-Log "tasks.json guncellendi" "SUCCESS"
}

# 1.2. Görev seç
if(!$TaskId){
    if(Test-Path build\tasks.json){
        $tasks = Get-Content build\tasks.json -Raw | ConvertFrom-Json
        $selectedTask = $tasks | Where-Object {$_.status -in @('todo','pending')} | Select-Object -First 1
        
        if($selectedTask){
            $TaskId = $selectedTask.id
            Write-Log "Task secildi: $TaskId - $($selectedTask.title)" "SUCCESS"
        } else {
            Write-Log "Aktif gorev yok (tum gorevler tamamlanmis)" "WARN"
            return
        }
    } else {
        Write-Log "build\tasks.json yok!" "ERROR"
        return
    }
}

if(!$TaskId){
    Write-Log "TaskId belirlenemedi!" "ERROR"
    return
}

Write-Log "SECILEN TASK: $TaskId" "INFO"

# ============================================================================
# DÖNGÜ BAŞLANGICI
# ============================================================================

for($round = 1; $round -le $MaxRounds; $round++){
    Write-Log "========================================"
    Write-Log "ROUND $round / $MaxRounds" "INFO"
    Write-Log "========================================"
    
    # ========================================================================
    # 2. TEST & RAPOR (Subset → Full)
    # ========================================================================
    
    Write-Log "[2/9] TEST & RAPOR" "INFO"
    
    # 2.1. Subset test (opsiyonel - Playwright varsa)
    if(Test-Path tests){
        Write-Log "Subset testler calistirilacak (TODO: npx playwright test --grep subset)" "WARN"
        # TODO: npx playwright test --config=playwright.config.ts --grep="@subset"
    }
    
    # 2.2. Universal report
    if(Test-Path ops\diagnostics\report_universal.ps1){
        try {
            & .\ops\diagnostics\report_universal.ps1 -TaskId $TaskId
            Write-Log "Rapor olusturuldu" "SUCCESS"
        } catch {
            Write-Log "Rapor hatasi: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # ========================================================================
    # 3. AGREGASYON (Dashboard, JUnit, Bundle)
    # ========================================================================
    
    Write-Log "[3/9] AGREGASYON" "INFO"
    
    if(Test-Path ops\run_universal_suite.ps1){
        try {
            & .\ops\run_universal_suite.ps1 -TaskId $TaskId
            Write-Log "Dashboard, JUnit ve Bundle olusturuldu" "SUCCESS"
        } catch {
            Write-Log "Suite hatasi: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # ========================================================================
    # 4. AI İSTEĞİ OLUŞTUR
    # ========================================================================
    
    Write-Log "[4/9] AI ISTEGI OLUSTURULUYOR" "INFO"
    
    if(Test-Path new_request.ps1){
        try {
            # Son raporu oku
            $latestReport = Get-ChildItem _otokodlama\reports\universal_findings_*.txt -ErrorAction SilentlyContinue |
                           Sort-Object LastWriteTime -Descending | Select-Object -First 1
            
            $description = if($latestReport){
                $reportContent = Get-Content $latestReport.FullName -Raw
                "Task: $TaskId`n`nRapor Özeti:`n$($reportContent.Substring(0, [Math]::Min(500, $reportContent.Length)))..."
            } else {
                "Task: $TaskId - Otomatik AI patch talebi"
            }
            
            & .\new_request.ps1 -TaskId $TaskId -Description $description
            Write-Log "AI request olusturuldu" "SUCCESS"
        } catch {
            Write-Log "Request olusturma hatasi: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # ========================================================================
    # 5. AI BRIDGE ÇAĞIR (Submit → Poll → Download)
    # ========================================================================
    
    Write-Log "[5/9] AI BRIDGE ($Mode)" "INFO"
    
    $bridgeSuccess = $false
    try {
        switch($Mode){
            'direct' {
                if(Test-Path ops\ai_bridge_http.ps1){
                    & .\ops\ai_bridge_http.ps1 -TaskId $TaskId `
                        -RequestsDir "_otokodlama\out" `
                        -InboxDir "_otokodlama\inbox"
                    $bridgeSuccess = $true
                    Write-Log "AI bridge (HTTP) OK" "SUCCESS"
                }
            }
            'github' {
                if(Test-Path ops\ai_bridge_github.ps1){
                    & .\ops\ai_bridge_github.ps1 -TaskId $TaskId
                    $bridgeSuccess = $true
                    Write-Log "AI bridge (GitHub) OK" "SUCCESS"
                }
            }
            'local' {
                Write-Log "Mode=local: patch_${TaskId}_*.zip'i _otokodlama\inbox'a manuel koy" "WARN"
                Write-Host "Patch hazir olunca ENTER'a bas..." -ForegroundColor Yellow
                Read-Host
                $bridgeSuccess = $true
            }
        }
    } catch {
        Write-Log "Bridge hatasi: $($_.Exception.Message)" "ERROR"
    }
    
    # ========================================================================
    # 6. RESPONSE → PATCH (JSON response'u ZIP'e çevir)
    # ========================================================================
    
    Write-Log "[6/9] RESPONSE ISLEME" "INFO"
    
    $patchZip = $null
    
    # 6.1. Response var mı?
    $response = Get-ChildItem "_otokodlama\inbox\response_${TaskId}_*.json" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if($response -and (Test-Path response_to_patch.ps1)){
        try {
            Write-Log "Response bulundu: $($response.Name)" "INFO"
            $patchZip = & .\response_to_patch.ps1 -ResponseFile $response.FullName -TaskId $TaskId
            Write-Log "Patch ZIP olusturuldu: $patchZip" "SUCCESS"
        } catch {
            Write-Log "Response->Patch hatasi: $($_.Exception.Message)" "ERROR"
        }
    } else {
        # 6.2. Doğrudan patch ZIP var mı?
        $existingPatch = Get-ChildItem "_otokodlama\inbox\patch_${TaskId}_*.zip" -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if($existingPatch){
            $patchZip = $existingPatch.FullName
            Write-Log "Patch ZIP mevcut: $patchZip" "INFO"
        }
    }
    
    # ========================================================================
    # 7. PATCH UYGULA (Whitelist, Zip-slip korumalı)
    # ========================================================================
    
    Write-Log "[7/9] PATCH UYGULA" "INFO"
    
    $patchApplied = $false
    if($patchZip -and (Test-Path $patchZip) -and (Test-Path ops\lib_patch.ps1)){
        try {
            & .\ops\lib_patch.ps1 -ZipPath $patchZip
            $patchApplied = $true
            Write-Log "Patch uygulandi: $patchZip" "SUCCESS"
        } catch {
            Write-Log "Patch uygulama hatasi: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "Patch ZIP yok veya lib_patch.ps1 eksik" "WARN"
    }
    
    # ========================================================================
    # 8. YENİDEN TEST & SONUÇ PAKETLEME
    # ========================================================================
    
    Write-Log "[8/9] YENIDEN TEST" "INFO"
    
    if($patchApplied){
        # Test tekrarı
        if(Test-Path ops\diagnostics\report_universal.ps1){
            try {
                & .\ops\diagnostics\report_universal.ps1 -TaskId $TaskId
                Write-Log "Yeniden test raporu olusturuldu" "SUCCESS"
            } catch {
                Write-Log "Test hatasi: $($_.Exception.Message)" "ERROR"
            }
        }
        
        # Agregasyon tekrar
        if(Test-Path ops\run_universal_suite.ps1){
            & .\ops\run_universal_suite.ps1 -TaskId $TaskId
        }
        
        # Gate kontrolü (JUnit)
        $latestGate = Get-ChildItem _otokodlama\reports\junit\gate_result_*.txt -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if($latestGate){
            $gateResult = Get-Content $latestGate.FullName -Raw
            Write-Log "Gate Result: $gateResult" $(if($gateResult -match 'PASS'){'SUCCESS'}else{'WARN'})
            
            # PASS ise solved yap
            if($gateResult -match 'PASS'){
                Update-Quarantine -TaskId $TaskId -Outcome "Success"
                Write-Log "Task solved: $TaskId" "SUCCESS"
                
                # CSV'de statü güncelle
                if(Test-Path tasks_template.csv){
                    $csv = Import-Csv tasks_template.csv
                    $csv | ForEach-Object {
                        if($_.id -eq $TaskId){ $_.status = 'solved' }
                    }
                    $csv | Export-Csv tasks_template.csv -NoTypeInformation -Encoding UTF8
                    Write-Log "tasks_template.csv guncellendi: $TaskId -> solved" "SUCCESS"
                }
                
                # Döngüden çık (solved)
                Write-Log "Task solved - dongu tamamlandi" "SUCCESS"
                break
            }
        }
    }
    
    # ========================================================================
    # 9. QUARANTINE GÜNCELLE
    # ========================================================================
    
    Write-Log "[9/9] QUARANTINE GUNCELLE" "INFO"
    
    $outcome = if($patchApplied){"Success"}else{"Fail"}
    try {
        Update-Quarantine -TaskId $TaskId -Outcome $outcome
        Write-Log "Quarantine: $TaskId -> $outcome" "INFO"
    } catch {
        Write-Log "Quarantine guncelleme hatasi: $($_.Exception.Message)" "ERROR"
    }
    
    Write-Log "Round $round tamamlandi`n" "INFO"
    Start-Sleep -Seconds 2
}

# ============================================================================
# DÖNGÜ SONU - ÖZET
# ============================================================================

$loopEndTime = Get-Date
$duration = $loopEndTime - $loopStartTime

Write-Log "========================================" "INFO"
Write-Log "AUTO LOOP TAMAMLANDI" "SUCCESS"
Write-Log "Sure: $($duration.TotalMinutes.ToString('F2')) dakika" "INFO"
Write-Log "========================================" "INFO"

# Son quarantine durumu
Write-Host "`n=== FINAL QUARANTINE STATUS ===" -ForegroundColor Cyan
. .\ops\quarantine.ps1
Get-Quarantine -TaskId $TaskId | Format-List

Write-Host "`n=== LOG ===" -ForegroundColor Cyan
Write-Host "Log dosyasi: $loopLogPath" -ForegroundColor Gray
