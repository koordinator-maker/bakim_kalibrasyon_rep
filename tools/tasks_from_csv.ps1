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

Write-Host "--- TASK DÖNÜŞTÜRÜCÜ BAŞLADI (V3 - ALAN TEMİZLİĞİ) ---" -ForegroundColor Yellow

try {
    # 1. CSV'yi oku
    # Raw oku ve sadece ilk satırdan başlıkları al, boşlukları temizle
    $rawContent = Get-Content $CsvPath -Encoding UTF8
    $headerLine = $rawContent[0].Trim()

    # Başlıkları boşluklarından temizle, sonra Import-Csv kullan
    $cleanHeaderLine = ($headerLine -split ',') | ForEach-Object { $_.Trim() } -join ','
    $cleanContent = @($cleanHeaderLine) + $rawContent[1..($rawContent.Count - 1)]

    $tasks = $cleanContent | ConvertFrom-Csv -Delimiter ','
    $requiredHeaders = "id", "title", "type", "design_ref", "visual_threshold"
    
    # Artık başlıklar temizlendiği için doğrudan kontrol edebiliriz
    $actualHeaders = $tasks[0].psobject.properties.Name
    $missingHeaders = $requiredHeaders | Where-Object { $actualHeaders -notcontains $_.ToLower() }

    if ($missingHeaders.Count -gt 0) {
        Write-Error "CSV'de zorunlu başlıklar eksik: "
        exit 1
    }

    # 2. JSON formatına dönüştür
    $output = @()
    foreach ($task in $tasks) {
        # Import-Csv alanları dinamik olarak okur, biz sadece TRIM ile boşlukları silelim
        $id = $task.id.Trim()
        $title = $task.title.Trim()
        $type = $task.type.Trim()
        $design_ref = $task.design_ref.Trim()
        $visual_threshold_str = $task.visual_threshold.Trim()

        if ([string]::IsNullOrEmpty($id) -or [string]::IsNullOrEmpty($title)) {
            Write-Warning "Boş ID veya Title içeren satır atlandı."
            continue
        }
        
        $visual_threshold = [double]::Parse($visual_threshold_str, [cultureinfo]::InvariantCulture)

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
    Write-Error "Dönüştürme sırasında hata oluştu: "
    exit 1
}
