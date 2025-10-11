param(
    [string]$BacklogPath = "ops/backlog.json",
    [string]$FlowsDir = "flows",
    [string]$FlowGenScript = "tools/pw_flow.py"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BacklogPath)) {
    Write-Error "Backlog dosyası bulunamadı: $BacklogPath"
    exit 1
}
if (-not (Test-Path $FlowsDir)) {
    New-Item -ItemType Directory -Path $FlowsDir | Out-Null
}
if (-not (Test-Path $FlowGenScript)) {
    Write-Error "Flow oluşturma betiği bulunamadı: $FlowGenScript"
    exit 1
}

Write-Host "[gen] Flow üretimi BAŞLADI." -ForegroundColor Yellow

try {
    $jsonContent = Get-Content $BacklogPath -Raw -Encoding UTF8
    $backlog = $jsonContent | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Backlog JSON dosyası okunamadı veya bozuk: "
    exit 1
}

$generatedCount = 0
foreach ($task in $backlog) {
    if (-not $task.id) {
        Write-Warning "Boş ID içeren görev atlandı."
        continue
    }

    $flowFileName = "_flow.json"
    $flowFilePath = Join-Path -Path $FlowsDir -ChildPath $flowFileName
    
    $tempTaskPath = "temp_task_.json" 
    (ConvertTo-Json $task -Depth 10) | Set-Content -Path $tempTaskPath -Encoding UTF8

    Write-Host "[DEBUG] Görev:  - Hedef dosya: $flowFilePath" -ForegroundColor DarkGray

    $pythonArgs = @(
        "-File", $FlowGenScript,
        "--task-file", $tempTaskPath,
        "--output", $flowFilePath
    )
    
    $result = python @($pythonArgs)
    
    if (-not (Test-Path $flowFilePath)) {
        Write-Warning "[WARN] $flowFileName oluşturulamadı. Python çıktısı: $result"
    } else {
        Write-Host "✅ $flowFileName başarıyla oluşturuldu." -ForegroundColor Green
        $generatedCount++
    }

    Remove-Item $tempTaskPath -ErrorAction SilentlyContinue
}

Write-Host "[gen] Flow üretimi TAMAMLANDI. Toplam üretilen: $generatedCount" -ForegroundColor Yellow

if ($generatedCount -gt 0) {
    exit 0
} else {
    exit 1
}
