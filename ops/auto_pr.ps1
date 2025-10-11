param(
  [string]$BaseBranch   = "main",
  [string]$Reviewer     = "ozkanrepo1",
  [string]$FeaturePrefix = "feat/auto-",
  [switch]$WaitForMerge,
  [int]$WaitTimeoutSec  = 600
)

$ErrorActionPreference = "Stop"

function Get-RepoSlug {
  $u = (& git remote get-url origin 2>$null)
  if (-not $u) { throw "origin remote yok" }
  if ($u -match 'github\.com[:/](.+?)(?:\.git)?$') { return $Matches[1] }
  throw "repo slug çözülemedi: $u"
}

# 0) Hazırlık
$slug   = Get-RepoSlug
$owner  = $slug.Split('/')[0]
$ts     = (Get-Date -Format "yyyyMMdd-HHmmss")
$branch = "$FeaturePrefix$ts"

# 1) Yeni feature dalı + küçük fark
git checkout -b $branch | Out-Null
New-Item -ItemType Directory -Force ".github" | Out-Null
"trigger $(Get-Date -Format s)" | Set-Content ".github\pr-bumper.md"
git add ".github\pr-bumper.md"
git commit -m "chore: auto bump for PR ($branch)" | Out-Null

# 2) Pipeline'ı feature dalına çalıştır (main'e push ETMEZ)
powershell -ExecutionPolicy Bypass -File "ops\pipeline_local.ps1" `
  -BaseUrl "http://127.0.0.1:8010" `
  -Branch  $branch `
  -BaseBranch $BaseBranch

# 3) Feature dalını push et
git push -u origin $branch

# 4) PR aç (varsa URL döner)
$title = "[auto] $branch"
$body  = "Auto PR"
$out = & gh pr create --title $title --body $body --base $BaseBranch --head $branch 2>&1
if ($LASTEXITCODE -ne 0) {
  $prUrl = ($out | Select-String -Pattern 'https?://github\.com/.+?/pull/\d+' | Select-Object -First 1).Matches.Value
  if (-not $prUrl) { throw "PR oluşturulamadı: $out" }
} else {
  $prUrl = ($out | Select-String -Pattern 'https?://github\.com/.+?/pull/\d+' | Select-Object -First 1).Matches.Value
}
Write-Host "[pr] $prUrl" -ForegroundColor Cyan

# 5) PR numarası
$pr = gh pr list --state open --head $branch --json number --jq '.[0].number'

# 6) Label + reviewer + auto-merge
gh label create "ui-tests" --color "5319e7" --description "UI pipeline checks" --force 2>$null | Out-Null
gh pr edit $pr --add-label ui-tests 2>$null | Out-Null
if ($Reviewer) { gh pr edit $pr --add-reviewer $Reviewer 2>$null | Out-Null }

# GH_TOKEN (ör. ozkanrepo1 PAT) bu oturumda set ise otomatik approve dene
if ($env:GH_TOKEN) {
  try { gh pr review $pr --approve | Out-Null } catch {}
}

gh pr merge $pr --squash --auto

# 7) Bekle & temizlik
if ($WaitForMerge) {
  $deadline = (Get-Date).AddSeconds($WaitTimeoutSec)
  do {
    Start-Sleep -Seconds 5
    $state = gh pr view $pr --json state --jq .state
    if ($state -eq "MERGED") { break }
  } while ((Get-Date) -lt $deadline)

  if ($state -eq "MERGED") {
    git checkout $BaseBranch | Out-Null
    git pull --rebase origin $BaseBranch | Out-Null
    git branch -D $branch 2>$null | Out-Null
    git push origin --delete $branch 2>$null | Out-Null
    Write-Host "[done] PR merged & branches cleaned." -ForegroundColor Green
  } else {
    Write-Warning "Merge bekleme süresi aşıldı (hala koşullar tamamlanmamış olabilir)."
  }
} else {
  Write-Host "[note] Auto-merge açık. Koşullar sağlanınca PR kendiliğinden birleşecek." -ForegroundColor Yellow
}
