# === csv_to_tasks.ps1 - CSV'den tasks.json oluştur ===
param(
    [string]$CSVPath = "tasks_template.csv",
    [string]$OutputPath = "build\tasks.json",
    [string[]]$StatusFilter = @('todo','pending')
)

if(!(Test-Path $CSVPath)){ 
    Write-Host "[WARN] CSV yok: $CSVPath - bos JSON olusturuluyor" -ForegroundColor Yellow
    '[]' | Set-Content $OutputPath -Encoding UTF8
    return
}

# CSV yükle
$tasks = Import-Csv $CSVPath -Encoding UTF8

# Filtreleme
$filtered = $tasks | Where-Object { $_.status -in $StatusFilter }

Write-Host "[INFO] $($tasks.Count) toplam gorev, $($filtered.Count) aktif (status in [$($StatusFilter -join ',')])" -ForegroundColor Gray

# JSON'a çevir
$filtered | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8

Write-Host "[OK] $($filtered.Count) gorev build\tasks.json'a yazildi" -ForegroundColor Green
