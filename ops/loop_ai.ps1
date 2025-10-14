# --- injected guards ---
if (-not $env:GH_BRANCH -or $env:GH_BRANCH -eq "") { $env:GH_BRANCH = "ai/UH001/live" }
if (-not $env:GH_REPO   -or $env:GH_REPO   -eq "") { throw "GH_REPO not set" }
$script:Branch   = $env:GH_BRANCH
$script:RepoSlug = $env:GH_REPO
try {
  $base = (git remote show origin | Select-String "HEAD branch:" | % { (($_ -split ":")[1]).Trim() })
} catch { $base =  }
if (-not $base -or $base -eq "") { $base = "main" }
function Get-LatestRunId([string]$Repo,[string]$Workflow,[string]$Branch){
  
    --json databaseId,status,displayTitle,headBranch 
    --jq '.[0].databaseId' 2>$null
}
# --- /injected ---
param(
  [string]$CsvPath = "todolist.csv",
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [ValidateSet("local","github")][string]$Mode = "local",
  [int]$MaxRounds = 3,
  [int]$InboxPollSeconds = 10,
  [int]$InboxWaitSeconds = 900,   # 15 dk
  [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Root {
  try { $r = (git rev-parse --show-toplevel) 2>$null } catch { $r = $null }
  if ($r -and (Test-Path $r)) { $r } else { (Get-Location).Path }
}

$root = Resolve-Root
Set-Location $root

if (!(Test-Path .\ops\loop_once.ps1)) { throw "Eksik: ops\loop_once.ps1" }
if (!(Test-Path .\ops\ai_bridge_github.ps1)) { throw "Eksik: ops\ai_bridge_github.ps1" }
. (Join-Path $PSScriptRoot 'ai_bridge_github.ps1')

New-Item -ItemType Directory -Force -Path "_otokodlama\inbox","_otokodlama\out" | Out-Null

function Get-LastResult {
  $j = Get-ChildItem -Path "_otokodlama\out" -Filter "ai_result_*.json" -File |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (!$j) { return $null }
  $obj = Get-Content -LiteralPath $j.FullName -Raw | ConvertFrom-Json
  [pscustomobject]@{
    Path = $j.FullName
    TaskId = $obj.task_id
    RequestPath = $obj.artifacts.ai_request
    BundlePath  = $obj.artifacts.bundle_zip
    ExitCode    = $obj.tests.exitCode
    Invoked     = $obj.tests.invoked
    ServerOk    = $obj.server_ok
  }
}

for ($round=1; $round -le $MaxRounds; $round++) {
  Write-Host ("=== ROUND {0}/{1} ===" -f $round,$MaxRounds)

  # loop_once.ps1 paramlarÄ±nÄ± Ã¼st scopeâ€™ta veriyoruz
  $script:CsvPath = $CsvPath
  $script:BaseUrl = $BaseUrl
  $script:NoPush  = $NoPush

  & "C:\dev\bakim_kalibrasyon\ops\loop_once.ps1"

  $res = Get-LastResult
  if (!$res) { throw "ai_result bulunamadÄ±." }
  if ([string]::IsNullOrWhiteSpace($res.TaskId)) { throw "TaskId boÅŸ geldi." }

  Write-Host ("Task: {0}, ExitCode(after first run) = {1}, ServerOK={2}" -f $res.TaskId,$res.ExitCode,$res.ServerOk)

  if ($Mode -eq "github") {
    $pub = Publish-AIRequestToGitHub -TaskId $res.TaskId -RequestPath $res.RequestPath -BundlePath $res.BundlePath -NoPush:$NoPush
    Write-Host ("GH publish: status={0} branch={1} pr={2}" -f $pub.status,$pub.branch,($pub.pr|Out-String).Trim())
  } else {
    Write-Host "LOCAL mode: AI cevabÄ±nÄ± _otokodlama\inbox altÄ±na bÄ±rakÄ±n (ZIP/TXT, adÄ±nda $($res.TaskId) geÃ§sin)."
  }

  $deadline = (Get-Date).AddSeconds($InboxWaitSeconds)
  $picked = $null
  while ((Get-Date) -lt $deadline) {
    $cands = Get-ChildItem -Path "_otokodlama\inbox" -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match [regex]::Escape($res.TaskId) }
    if ($cands) {
      $picked = ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
      break
    }
    Start-Sleep -Seconds $InboxPollSeconds
  }

  if (!$picked) {
    Write-Warning "Inbox'ta $($res.TaskId) iÃ§in patch bulunamadÄ±; round tamamlandÄ±."
    continue
  } else {
    Write-Host ("Patch bulundu: {0}" -f $picked.FullName)
  }

  # Patchâ€™i uygulayÄ±p test ediyoruz (TaskId vererek)
  $script:TaskId = $res.TaskId
  & "C:\dev\bakim_kalibrasyon\ops\loop_once.ps1"

  $res2 = Get-LastResult
  if (!$res2) { throw "Ä°kinci sonuÃ§ dosyasÄ± yok." }
  Write-Host ("After patch: ExitCode={0} (0=PASS)" -f $res2.ExitCode)

  if ($res2.ExitCode -eq 0) {
    Write-Host "ğŸ‰ TÃ¼m testler geÃ§ti. DÃ¶ngÃ¼ tamamlandÄ±."
    break
  } else {
    Write-Host "â— Testler hala kÄ±rÄ±k. SonuÃ§lar AI'ye yeniden iletilecek (sonraki round)."
  }
}

# --- injected: safe artifact poll (JSON) ---
try {
  Remove-Item -ErrorAction SilentlyContinue _otokodlama\inbox\patch_*.zip
  $wf   = "ai-patch-agent.yml"
  $rid  = $null
  $till = (Get-Date).AddMinutes(5)
  do {
    Start-Sleep 5
    $rid = Get-LatestRunId -Repo $script:RepoSlug -Workflow $wf -Branch $script:Branch
  } while(-not $rid -and (Get-Date) -lt $till)
  if($rid){
    $names = gh api repos/$script:RepoSlug/actions/runs/$rid/artifacts --jq '.artifacts[].name' 2>$null
    if($names -match '^patch_zip$'){
      gh run download $rid -R $script:RepoSlug -n patch_zip -D _otokodlama\inbox | Out-Null
      Write-Host "GH publish: patch_zip indirildi."
    } else {
      Write-Host ("GH publish: artifact listesi: " + $names)
    }
  } else {
    Write-Host ("GH publish: run bulunamadı (workflow=$wf, branch="+$script:Branch+")")
  }
} catch { Write-Host ("GH publish: artifact indirme hatasi: " + $_.Exception.Message) }
# --- /injected ---
