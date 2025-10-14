param(
  [string]$CsvPath = "todolist.csv",
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [ValidateSet("local","github")][string]$Mode = "github",
  [int]$MaxRounds = 999,
  [int]$InboxWaitSeconds = 600
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
# Guards
if ($Mode -eq 'github') {
  if (-not $env:GH_BRANCH -or $env:GH_BRANCH -eq "") { $env:GH_BRANCH = "ai/UH001/live" }
  if (-not $env:GH_REPO   -or $env:GH_REPO   -eq "") { throw "GH_REPO not set" }
}
$script:Branch   = $env:GH_BRANCH
$script:RepoSlug = $env:GH_REPO
try {
  $base = (git remote show origin | Select-String "HEAD branch:" | ForEach-Object { (($_ -split ":")[1]).Trim() })
} catch { $base = $null }
if (-not $base -or $base -eq "") { $base = "main" }
function Get-LatestRunId([string]$Repo,[string]$Workflow,[string]$Branch){
  gh run list -R $Repo --workflow $Workflow -b $Branch --limit 1 `
    --json databaseId,status,displayTitle,headBranch `
    --jq '.[0].databaseId' 2>$null
}
function Log([string]$m){ Write-Host $m }
for($round=1; $round -le $MaxRounds; $round++){
  Log ("=== ROUND {0}/{1} ===" -f $round,$MaxRounds)
  # 1) Tespit/özet → ai_request üret (başarısız olsa da döngü sürer)
  try {
    powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\ai_request_enricher.ps1" -TaskId "UH001" | Out-Null
  } catch {
    Log ("[warn] enricher: " + $_.Exception.Message)
  }
  if ($Mode -eq 'github') {
    # 2) Yayınla (branch push + PR garanti + agent tetik + artefakt poller)
    & "$PSScriptRoot\ai_bridge_github.ps1"
    # 3) Ek güvence: patch_zip artefaktını son run'dan çek (JSON runId)
    try {
      $rid = Get-LatestRunId -Repo $script:RepoSlug -Workflow "ai-patch-agent.yml" -Branch $script:Branch
      if ($rid) {
        $names = gh api repos/$script:RepoSlug/actions/runs/$rid/artifacts --jq '.artifacts[].name' 2>$null
        if ($names -match '^patch_zip$') {
          Remove-Item -ErrorAction SilentlyContinue "_otokodlama\inbox\patch_*.zip"
          gh run download $rid -R $script:RepoSlug -n patch_zip -D _otokodlama\inbox | Out-Null
          Log "[bridge] patch_zip indirildi."
        } else {
          Log ("[bridge] artifacts: " + $names)
        }
      }
    } catch { Log ("[bridge] artifact poll error: " + $_.Exception.Message) }
  }
  # 4) Patch uygula (varsa)
  $zip = Get-ChildItem "_otokodlama\inbox" -Filter "patch_*.zip" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if ($zip) {
    powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\apply_patch_zip.ps1" -ZipPath $zip.FullName | Out-Null
  }
  # 5) Bekle ve sonraki tura geç
  Start-Sleep -Seconds $InboxWaitSeconds
}