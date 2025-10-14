# --- injected: ensure base branch ---
try {
  $base = (git remote show origin | Select-String "HEAD branch:" | % { ($_ -split ":")[1].Trim() })
} catch { $base = $null }
if (-not $base) { $base = "main" }
# --- /injected ---
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

  if (-not (Test-Path $RequestPath)) { throw "AI istek dosyasÄ± yok: $RequestPath" }
  if (-not (Test-Path $BundlePath))  { throw "Bundle dosyasÄ± yok: $BundlePath" }

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
  if (-not $gh) { return @{ status="pushed"; branch=$branch; note="gh CLI yok; PR manuel aÃ§Ä±lmalÄ±." } }

  $body = @"
**AI Request for $TaskId** â€” $ts

Bu PR, AI tarafÄ±na analiz ve patch Ã¼retimi iÃ§in aÃ§Ä±ldÄ±.
Ä°Ã§erik:
- JSON ve Zip: \`$relDir\`

YanÄ±t/patche'i **\`_otokodlama/inbox\`** altÄ±na \`$TaskId\` geÃ§en bir **ZIP/TXT** olarak bÄ±rakÄ±n
(Ã¶rn: \`_otokodlama/inbox/patch_${TaskId}_$ts.zip\`). Otomasyon patch'i uygulayÄ±p test edecektir.
"@

  $tmp = Join-Path $env:TEMP ("ai_pr_{0}_{1}.md" -f $TaskId,$ts)
  Write-Utf8 $tmp $body

  $prUrl = ""
  try { $prUrl = (gh pr create --base $MainBranch --head $branch --title ("AI: {0} request {1}" -f $TaskId,$ts) --body-file $tmp -q ".url") } catch { }

  return @{ status="pushed"; branch=$branch; pr=$prUrl }
}

# ensure PR exists for the live branch
Ensure-PR -Repo $env:GH_REPO -Base $base -Head $env:GH_BRANCH

## artifact pull
try {
  Remove-Item -ErrorAction SilentlyContinue _otokodlama\inbox\patch_*.zip
  $wf = "ai-patch-agent.yml"
  $repoSlug = $env:GH_REPO
  # Son run'ı bul (workflow filtresi + branch)
  for($i=0;$i -lt 30;$i++){
    Start-Sleep 5
    $run = gh run list -R $repoSlug --workflow $wf -b $env:GH_BRANCH --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null
    if($run){ break }
  }
  if($run){
    $names = gh api repos/$repoSlug/actions/runs/$run/artifacts --jq '.artifacts[].name'
    if($names -match '^patch_zip$'){
      gh run download $run -R $repoSlug -n patch_zip -D _otokodlama\inbox | Out-Null
      Write-Host "GH publish: patch_zip indirildi."
    } else {
      Write-Host ("GH publish: artifact listesi: " + $names)
    }
  }
} catch { Write-Host ("GH publish: artifact indirme hatasi: " + $_.Exception.Message) }
