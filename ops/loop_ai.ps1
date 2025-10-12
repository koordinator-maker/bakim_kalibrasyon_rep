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

  # loop_once.ps1 paramlarını üst scope’ta veriyoruz
  $script:CsvPath = $CsvPath
  $script:BaseUrl = $BaseUrl
  $script:NoPush  = $NoPush

  & .\ops\loop_once.ps1

  $res = Get-LastResult
  if (!$res) { throw "ai_result bulunamadı." }
  if ([string]::IsNullOrWhiteSpace($res.TaskId)) { throw "TaskId boş geldi." }

  Write-Host ("Task: {0}, ExitCode(after first run) = {1}, ServerOK={2}" -f $res.TaskId,$res.ExitCode,$res.ServerOk)

  if ($Mode -eq "github") {
    $pub = Publish-AIRequestToGitHub -TaskId $res.TaskId -RequestPath $res.RequestPath -BundlePath $res.BundlePath -NoPush:$NoPush
    Write-Host ("GH publish: status={0} branch={1} pr={2}" -f $pub.status,$pub.branch,($pub.pr|Out-String).Trim())
  } else {
    Write-Host "LOCAL mode: AI cevabını _otokodlama\inbox altına bırakın (ZIP/TXT, adında $($res.TaskId) geçsin)."
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
    Write-Warning "Inbox'ta $($res.TaskId) için patch bulunamadı; round tamamlandı."
    continue
  } else {
    Write-Host ("Patch bulundu: {0}" -f $picked.FullName)
  }

  # Patch’i uygulayıp test ediyoruz (TaskId vererek)
  $script:TaskId = $res.TaskId
  & .\ops\loop_once.ps1

  $res2 = Get-LastResult
  if (!$res2) { throw "İkinci sonuç dosyası yok." }
  Write-Host ("After patch: ExitCode={0} (0=PASS)" -f $res2.ExitCode)

  if ($res2.ExitCode -eq 0) {
    Write-Host "🎉 Tüm testler geçti. Döngü tamamlandı."
    break
  } else {
    Write-Host "❗ Testler hala kırık. Sonuçlar AI'ye yeniden iletilecek (sonraki round)."
  }
}
