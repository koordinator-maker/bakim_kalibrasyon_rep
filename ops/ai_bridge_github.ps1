Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
# Guards
if (-not $env:GH_BRANCH -or $env:GH_BRANCH -eq "") { $env:GH_BRANCH = "ai/UH001/live" }
if (-not $env:GH_REPO   -or $env:GH_REPO   -eq "") { throw "GH_REPO not set" }
$script:Branch   = $env:GH_BRANCH
$script:RepoSlug = $env:GH_REPO
try {
  $base = (git remote show origin | Select-String "HEAD branch:" | ForEach-Object { (($_ -split ":")[1]).Trim() })
} catch { $base = $null }
if (-not $base -or $base -eq "") { $base = "main" }
function Ensure-PR([string]$Repo,[string]$Base,[string]$Head) {
  $url = gh pr list -R $Repo -H $Head --json url --jq '.[0].url' 2>$null
  if (-not $url -or $url -eq "") {
    gh pr create -R $Repo -B $Base -H $Head -t "AI: $Head" -b "auto" --draft | Out-Null
  }
}
function Get-LatestRunId([string]$Repo,[string]$Workflow,[string]$Branch){
  gh run list -R $Repo --workflow $Workflow -b $Branch --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null
}
# 1) Yayınla
git fetch --all --prune | Out-Null
git checkout -B $script:Branch | Out-Null
$changed = (git status --porcelain)
if (-not $changed) {
  $ping = "ai_exchange/__trigger.txt"
  $msg  = "trigger $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $dir  = Split-Path $ping
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($ping,$msg,[Text.UTF8Encoding]::new($false))
  git add -- $ping
  git commit -m "ci(ai): touch trigger" | Out-Null
} else {
  git add --all
  git commit -m "ci(ai): publish artifacts" | Out-Null
}
git push -u origin $script:Branch
# 2) PR'ı garanti et
Ensure-PR -Repo $script:RepoSlug -Base $base -Head $script:Branch | Out-Null
# 3) Workflow'u tetikle
gh workflow run ".github/workflows/ai-patch-agent.yml" --ref $script:Branch | Out-Null
# 4) PR bilgisini yaz
try {
  $pr = gh pr view $script:Branch --repo $script:RepoSlug --json url --jq .url 2>$null
  Write-Host ("GH publish: status=pushed branch="+$script:Branch+" pr="+$pr)
} catch {
  Write-Host ("GH publish: status=pushed branch="+$script:Branch+" pr=")
}
# 5) Artefakt: patch_zip'i JSON runId ile indir
$deadline = (Get-Date).AddMinutes(5)
$rid = $null
do {
  Start-Sleep 5
  $rid = Get-LatestRunId -Repo $script:RepoSlug -Workflow "ai-patch-agent.yml" -Branch $script:Branch
} while (-not $rid -and (Get-Date) -lt $deadline)
if ($rid) {
  $names = gh api repos/$script:RepoSlug/actions/runs/$rid/artifacts --jq '.artifacts[].name' 2>$null
  if ($names -match '^patch_zip$') {
    Remove-Item -ErrorAction SilentlyContinue _otokodlama\inbox\patch_*.zip
    gh run download $rid -R $script:RepoSlug -n patch_zip -D _otokodlama\inbox | Out-Null
    Write-Host "GH publish: patch_zip indirildi."
  } else {
    Write-Host ("GH publish: artifact listesi: " + $names)
  }
} else {
  Write-Host "GH publish: run bulunamadı."
}