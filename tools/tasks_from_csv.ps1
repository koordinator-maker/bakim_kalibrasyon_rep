param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,

    [string]$JsonPath = "plan/tasks.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV dosyası bulunamadı: $CsvPath"
    exit 1
}

if (-not (Test-Path "plan")) {
    New-Item -ItemType Directory -Path "plan" | Out-Null
}

Write-Host "--- TASK DÖNÜŞTÜRÜCÜ BAŞLADI (V4 - ONARIM) ---" -ForegroundColor Yellow

try {
    # 1. CSV'yi oku ve başlıkları temizle (V3'teki gibi)
    $rawContent = Get-Content $CsvPath -Encoding UTF8
    $headerLine = $rawContent[0].Trim()
    $cleanHeaderLine = ($headerLine -split ',') | ForEach-Object { $_.Trim() } -join ','
    $cleanContent = @($cleanHeaderLine) + $rawContent[1..($rawContent.Count - 1)]

    $tasks = $cleanContent | ConvertFrom-Csv -Delimiter ','
    $requiredHeaders = "id", "title", "type", "design_ref", "visual_threshold"
    
    $actualHeaders = $tasks[0].psobject.properties.Name
    $missingHeaders = $requiredHeaders | Where-Object { $actualHeaders -notcontains $_.ToLower() }

    if ($missingHeaders.Count -gt 0) {
        Write-Error "CSV'de zorunlu başlıklar eksik: "
        exit 1
    }

    # 2. JSON formatına dönüştür
    $output = @()
    foreach ($task in $tasks) {
        $id = $task.id.Trim()
        $title = $task.title.Trim()
        $type = $task.type.Trim()
        $design_ref = $task.design_ref.Trim()
        $visual_threshold_str = $task.visual_threshold.Trim()

        if ([string]::IsNullOrEmpty($id) -or [string]::IsNullOrEmpty($title)) {
            Write-Warning "Boş ID veya Title içeren satır atlandı."
            continue
        }
        
        # Olası kültür sorununu gidermek için: Virgülleri noktaya çevir, sonra dönüştür.
        $clean_threshold_str = $visual_threshold_str.Replace(',', '.')
        $visual_threshold = [double]::Parse($clean_threshold_str, [cultureinfo]::InvariantCulture)

        $taskObject = [PSCustomObject]@{
            id = $id
            title = $title
            type = $type
            design_ref = $design_ref
            visual_threshold = $visual_threshold
        }
        $output += $taskObject
    }

    # 3. JSON'a yaz
    $output | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8
    
    Write-Host "✅ Başarılı: 0 görev $JsonPath dosyasına kaydedildi." -ForegroundColor Green
    Write-Host "--- TASK DÖNÜŞTÜRÜCÜ BİTTİ ---" -ForegroundColor Yellow
}
catch {
    # Hatanın kendisini açıkça yazdır (Dönüşüm hatasını yakalamak için)
    Write-Error "Dönüştürme sırasında KRİTİK HATA oluştu: "
    exit 1
}
