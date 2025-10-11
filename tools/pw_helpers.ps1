Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-PwCmd { param([string]$ArgsLine) & cmd /c "npx $ArgsLine"; if ($LASTEXITCODE -ne 0){ throw "Playwright exit code: $LASTEXITCODE" } }

function Invoke-PwByFileBase {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$FileBases,[string]$Project='chromium',[string]$Reporter='line,html')
    $escaped = $FileBases | ForEach-Object { ($_ -replace '([.^$+(){}|\[\]\\])','\$1') }
    $regex   = "(^|[\\/])(" + ($escaped -join '|') + ")$"
    Write-Host "▶ Running by file base:" ($FileBases -join ', ')
    Invoke-PwCmd "playwright test ""$regex"" --project=$Project --reporter `"$Reporter`""
}

function Invoke-PwSmart {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FileBase,[string]$Project='chromium',[string]$Reporter='line,html')
    $escFile  = [regex]::Escape($FileBase)
    $fileExpr = "(^|[\\/])$escFile$"          # 1) dosya filtresi
    # Sadece hedef dosyayı listeden tara:
    $list = (& cmd /c "npx playwright test ""$fileExpr"" --list" 2>&1) | Out-String

    $titles = @()
    foreach($ln in ($list -split "`r?`n")){
        if ($ln -match "›\s+${escFile}:\d+:\d+\s+›\s+(.*)$" -or
            $ln -match ">\s+${escFile}:\d+:\d+\s+>\s+(.*)$") { $titles += $Matches[1].Trim() }
    }

    if ($titles.Count -gt 0) {
        $safe = $titles | Sort-Object -Unique | ForEach-Object { [regex]::Escape($_) }
        $grep = '(' + ($safe -join '|') + ')'              # 2) başlık filtresi
        Write-Host "▶ titles→grep:" $FileBase
        # 3) KOŞARKEN DE dosya filtresi + grep birlikte
        Invoke-PwCmd "playwright test ""$fileExpr"" --project=$Project --reporter `"$Reporter`" --grep ""$grep"""
    } else {
        Write-Host "ℹ Başlık yok, dosya bazlı koşuluyor:" $FileBase
        Invoke-PwCmd "playwright test ""$fileExpr"" --project=$Project --reporter `"$Reporter`""
    }
}

function adminOnly { Invoke-PwByFileBase -FileBases @('admin-dashboard.spec.js') }
function eqp002    { Invoke-PwByFileBase -FileBases @('EQP-002.spec.js') }
function eqp003    { Invoke-PwByFileBase -FileBases @('EQP-003.spec.js') }
function eqpBoth   { Invoke-PwByFileBase -FileBases @('EQP-002.spec.js','EQP-003.spec.js') }
