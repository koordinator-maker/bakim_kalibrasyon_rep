function Ensure-PR {
  param([string]$Repo,[string]$Base,[string]$Head)
  $url = gh pr list -R $Repo -H $Head --json url --jq ".[0].url"
  if(-not $url -or $url -eq "") {
    gh pr create -R $Repo -B $Base -H $Head -t "AI: $Head" -b "auto" --draft | Out-Null
  }
}
# ops/ai_bridge_github.ps1  (Windows PowerShell 5.1)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Root {
  try { $r = (git rev-parse --show-toplevel) 2>$null } catch { $r = $null }
  if ($r -and (Test-Path $r)) { return $r } else { return (Get-Location).Path }
}

function Write-Utf8([string]$Path,[string]$Content){
  $Utf8NoBom = [Text.UTF8Encoding]::new($false)
  if ([string]::IsNullOrWhiteSpace($Path)) { throw "Write-Utf8: empty path" }
  $full = $Path
  if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path -Path ((Get-Location).Path) -ChildPath $full }
  $full = [IO.Path]::GetFullPath($full)
  $dir  = [IO.Path]::GetDirectoryName($full)
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($full,$Content,$Utf8NoBom)
}

function Publish-AIRequestToGitHub {
  param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [Parameter(Mandatory=$true)][string]$RequestPath,
    [Parameter(Mandatory=$true)][string]$BundlePath,
    [string]$MainBranch="main",
    [string]$Remote="origin",
    [string]$ExchangeDir="ai_exchange",
    [switch]$NoPush
  )

  $root = Resolve-Root
  Set-Location $root

  if (-not (Test-Path $RequestPath)) { throw "AI istek dosyası yok: $RequestPath" }
  if (-not (Test-Path $BundlePath))  { throw "Bundle dosyası yok: $BundlePath" }

  $ts = Get-Date -Format yyyyMMdd-HHmmss
  $relDir = Join-Path $ExchangeDir (Join-Path $TaskId $ts)
  New-Item -ItemType Directory -Force -Path $relDir | Out-Null

  Copy-Item -LiteralPath $RequestPath -Destination (Join-Path $relDir (Split-Path $RequestPath -Leaf)) -Force
  Copy-Item -LiteralPath $BundlePath  -Destination (Join-Path $relDir (Split-Path $BundlePath  -Leaf)) -Force

  $branch = "ai/$TaskId/$ts"
  & git checkout -q -b $branch | Out-Null
  & git add -A | Out-Null
  $st = (git status --porcelain)
  if ([string]::IsNullOrWhiteSpace($st)) { return @{ status="no-change"; branch=$branch } }

  & git commit -m ("ai: {0} request {1}" -f $TaskId,$ts) | Out-Null
  if ($NoPush) { return @{ status="committed"; branch=$branch } }

  & git push -u $Remote $branch | Out-Null

  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $gh) { return @{ status="pushed"; branch=$branch; note="gh CLI yok; PR manuel açılmalı." } }

  $body = @"
**AI Request for $TaskId** — $ts

Bu PR, AI tarafına analiz ve patch üretimi için açıldı.
İçerik:
- JSON ve Zip: \`$relDir\`

Yanıt/patche'i **\`_otokodlama/inbox\`** altına \`$TaskId\` geçen bir **ZIP/TXT** olarak bırakın
(örn: \`_otokodlama/inbox/patch_${TaskId}_$ts.zip\`). Otomasyon patch'i uygulayıp test edecektir.
"@

  $tmp = Join-Path $env:TEMP ("ai_pr_{0}_{1}.md" -f $TaskId,$ts)
  Write-Utf8 $tmp $body

  $prUrl = ""
  try { $prUrl = (gh pr create --base $MainBranch --head $branch --title ("AI: {0} request {1}" -f $TaskId,$ts) --body-file $tmp -q ".url") } catch { }

  return @{ status="pushed"; branch=$branch; pr=$prUrl }
}

Ensure-PR -Repo $env:GH_REPO -Base $base -Head $env:GH_BRANCH
