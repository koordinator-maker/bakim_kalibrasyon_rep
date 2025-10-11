param(
    [string]$FlowsDir = "flows",
    [string]$Filter = "*",
    [string]$BaseUrl = "http://127.0.0.1:8010",
    [bool]$LinkSmoke = $false,
    [int]$SmokeDepth = 1,
    [int]$SmokeLimit = 200,
    [string]$ExtraArgs = ""
)

$ErrorActionPreference = "Stop"

Write-Host "[run] Filters: $Filter" -ForegroundColor Yellow

$flowFiles = Get-ChildItem -Path $FlowsDir -Filter "*_flow.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $Filter.Replace('*', '*') + "_flow.json" }

if ($flowFiles.Count -eq 0) {
    Write-Host "[run] Akış bulunamadı. Aranılan dizin: $FlowsDir" -ForegroundColor Red
    Write-Host "[DEBUG] Filtre: $Filter.Replace('*', '*') + '_flow.json'" -ForegroundColor DarkGray
    exit 1
}

Write-Host "[run] 0 adet akış bulundu. Başlatılıyor..." -ForegroundColor Green

foreach ($file in $flowFiles) {
    $flowPath = $file.FullName
    $id = $file.BaseName -replace '_flow$'

    Write-Host "--- Başlatılıyor: $id ($flowPath) ---" -ForegroundColor Cyan
    
    $args = @(
        "npx", 
        "playwright", 
        "flow", 
        "run", 
        "", 
        "--base-url", 
        ""
    )

    if ($LinkSmoke) {
        $args += @(
            "--extra-command", 
            "powershell -ExecutionPolicy Bypass -File ops/smoke_links.ps1 -TargetUrl "" -TargetFlow "" -SmokeDepth $SmokeDepth -SmokeLimit $SmokeLimit -OkRedirectTo /_direct/.*",
            "--log-file",
            "logs/$id_smoke_$(Get-Date -Format 'yyyyMMddHHmmss').log"
        )
    }

    if ($ExtraArgs) {
        $args += $ExtraArgs.Split(' ') | Where-Object { -not [string]::IsNullOrEmpty($_) }
    }

    $commandLine = $args -join ' '
    Write-Host "[DEBUG] Çalıştırılan Komut: $commandLine" -ForegroundColor DarkGray
    
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $commandLine" -NoNewWindow -PassThru -Wait -RedirectStandardOutput "logs/$id_pw_$(Get-Date -Format 'yyyyMMddHHmmss').log" -RedirectStandardError "logs/$id_error_$(Get-Date -Format 'yyyyMMddHHmmss').log"
    
    if ($process.ExitCode -eq 0) {
        Write-Host "✅ Başarılı: $id" -ForegroundColor Green
    } else {
        Write-Host "❌ Başarısız: $id (Exit Kodu: $(.ExitCode))" -ForegroundColor Red
    }
}

Write-Host "--- Koşucu BİTTİ ---" -ForegroundColor Yellow
