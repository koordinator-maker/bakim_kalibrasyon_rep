Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Playwright çağrıları: --% KULLANMIYORUZ (değişkenler genişlesin) --
function Invoke-PwByFileBase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$FileBases,                 # ör: 'EQP-002.spec.js','admin-dashboard.spec.js'
        [string]$Project  = 'chromium',
        [string]$Reporter = 'line,html'
    )

    # Özel regex karakterlerini kaçır (tek tırnak -> $1 değişken sanmasın)
    $escaped = $FileBases | ForEach-Object { ($_ -replace '([.^$+(){}|\[\]\\])','\$1') }
    $regex   = "(^|[\\/])(" + ($escaped -join '|') + ")$"

    Write-Host "▶ Running by file base:" ($FileBases -join ', ')

    $args = @('playwright','test', $regex, "--project=$Project", '--reporter', $Reporter)
    & npx @args
}

function Invoke-PwSmart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FileBase,  # 'EQP-003.spec.js' vb.
        [string]$Project  = 'chromium',
        [string]$Reporter = 'line,html'
    )

    $esc = [regex]::Escape($FileBase)
    $list = (& npx playwright test --list 2>&1) -join [Environment]::NewLine
    $titles = @()

    foreach($ln in ($list -split "`r?`n")){
        if ($ln -match "›\s+${esc}:\d+:\d+\s+›\s+(.*)$" -or
            $ln -match ">\s+${esc}:\d+:\d+\s+>\s+(.*)$") {
            $titles += $Matches[1].Trim()
        }
    }

    if ($titles.Count -gt 0) {
        $safe = $titles | Sort-Object -Unique | ForEach-Object { [regex]::Escape($_) }
        $grep = '(' + ($safe -join '|') + ')'
        Write-Host "▶ titles→grep:" $FileBase
        $args = @('playwright','test', "--project=$Project", '--reporter', $Reporter, '--grep', $grep)
        & npx @args
    } else {
        $regex = "(^|[\\/])" + $esc + "$"
        Write-Host "ℹ Başlık yok, dosya bazlı koşuluyor:" $FileBase
        $args = @('playwright','test', $regex, "--project=$Project", '--reporter', $Reporter)
        & npx @args
    }
}

# Kısayollar (adlandırılmış argümanla)
function adminOnly { Invoke-PwByFileBase -FileBases @('admin-dashboard.spec.js') }
function eqp002    { Invoke-PwByFileBase -FileBases @('EQP-002.spec.js') }
function eqp003    { Invoke-PwByFileBase -FileBases @('EQP-003.spec.js') }
function eqpBoth   { Invoke-PwByFileBase -FileBases @('EQP-002.spec.js','EQP-003.spec.js') }
