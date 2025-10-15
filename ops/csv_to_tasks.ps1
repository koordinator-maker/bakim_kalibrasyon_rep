# === csv_to_tasks.ps1 - CSV'den tasks.json (PS5.1 safe) ===
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
$tasks = @(Import-Csv $CSVPath -Encoding UTF8)

# Filtreleme
$filtered = @($tasks | Where-Object { $_.status -in $StatusFilter })

# PS5.1 safe count
$totalCount = $tasks.Count
if($tasks -isnot [Array]){ $totalCount = 1 }

$filteredCount = $filtered.Count
if($filtered -isnot [Array] -and $filtered){ $filteredCount = 1 }
elseif(!$filtered){ $filteredCount = 0 }

Write-Host "[INFO] $totalCount toplam gorev, $filteredCount aktif (status in [$($StatusFilter -join ',')])" -ForegroundColor Gray

# JSON'a çevir
if($filteredCount -gt 0){
    $filtered | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
} else {
    '[]' | Set-Content $OutputPath -Encoding UTF8
}

Write-Host "[OK] $filteredCount gorev build\tasks.json'a yazildi" -ForegroundColor Green
