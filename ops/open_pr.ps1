param(
  [string]$RepoRoot   = ".",
  [string]$Branch     = "main",   # PR HEAD (çalıştığınız dal)
  [string]$BaseBranch = "main",   # PR BASE (hedef dal)
  [string]$StateTools = "ops/state_tools.ps1"
)

$ErrorActionPreference = "Stop"

function Show-GitHubErrorBody {
  param([System.Net.WebException]$Ex)
  try {
    $resp = $Ex.Response
    if ($resp -and $resp.GetResponseStream) {
      $sr = New-Object IO.StreamReader($resp.GetResponseStream())
      $body = $sr.ReadToEnd()
      Write-Warning ("GitHub API error body: " + $body)
      if ($resp.Headers["WWW-Authenticate"]) {
        Write-Warning ("WWW-Authenticate: " + $resp.Headers["WWW-Authenticate"])
      }
    }
  } catch { Write-Warning "Error body okunamadı: $($_.Exception.Message)" }
}

function Get-RepoSlug {
  param([string]$RepoRoot)
  Push-Location $RepoRoot
  try {
    $url = (& git remote get-url origin 2>$null)
    if (-not $url) { throw "origin remote bulunamadı." }
    if ($url -match 'github\.com[:/](.+?)(\.git)?$') { return $Matches[1] }
    throw "GitHub repo slug çözülemedi: $url"
  } finally { Pop-Location }
}

function Load-State {
  param([string]$StateTools,[string]$RepoRoot)
  . (Join-Path $RepoRoot $StateTools)
  return (Get-State)
}

function Build-PR-Body {
  param($state)
  $lines = @()
  $lines += "### UI Test Özeti"
  if ($state.tests -and $state.tests.summary) {
    $lines += ""
    $lines += "- **Passed**: $($state.tests.summary.passed)"
    $lines += "- **Failed**: $($state.tests.summary.failed)"
    $lines += "- **Last Run**: $($state.tests.summary.last_run)"
  }

  if ($state.tests -and $state.tests.results) {
    $lines += ""
    $lines += "| Key | Status | words_recall | missing_count | out_json | screenshot |"
    $lines += "|-----|--------|--------------|---------------|----------|------------|"

    $keys = @()
    if ($state.tests.results -is [hashtable]) { $keys = $state.tests.results.Keys }
    else { $keys = ($state.tests.results.PSObject.Properties | Select-Object -ExpandProperty Name) }

    foreach ($k in $keys) {
      $it = if ($state.tests.results -is [hashtable]) { $state.tests.results[$k] } else { $state.tests.results.$k }
      $status = $it.status
      $recall = ""
      $misses = ""
      if ($it.metrics) {
        if ($it.metrics.PSObject.Properties['words_recall']) { $recall = [string]$it.metrics.words_recall }
        if ($it.metrics.PSObject.Properties['missing_count']) { $misses = [string]$it.metrics.missing_count }
      }
      $outj = ""
      $shot = ""
      if ($it.artifacts) {
        if ($it.artifacts.PSObject.Properties['out_json']) { $outj = [string]$it.artifacts.out_json }
        if ($it.artifacts.PSObject.Properties['screenshot']) { $shot = [string]$it.artifacts.screenshot }
      }
      $lines += "| $k | $status | $recall | $misses | $outj | $shot |"
    }
  }

  if ($state.pending_actions -and $state.pending_actions.Count -gt 0) {
    $lines += ""
    $lines += "### Pending Actions"
    foreach ($p in $state.pending_actions) {
      $lines += "- [$($p.status)] **$($p.type)**: $($p.detail) (due_stage: $($p.due_stage), ts: $($p.ts))"
    }
  }

  return ($lines -join "`n")
}

# ----- MAIN -----
$repoSlug = Get-RepoSlug -RepoRoot $RepoRoot
$state    = Load-State -StateTools $StateTools -RepoRoot $RepoRoot

$title = "[auto] UI validate passed → open PR"
$body  = Build-PR-Body -state $state

# 1) Push edildiğinden emin ol
Push-Location $RepoRoot
try { & git push origin $Branch | Out-Null } finally { Pop-Location }

# 2) PR açma: gh (CLI) → yoksa REST → ikisi de yoksa uyarı
$createdUrl = ""
$used = ""

if (Get-Command gh -ErrorAction SilentlyContinue) {
  try {
    $out = & gh pr create --title $title --body $body --base $BaseBranch --head $Branch 2>&1
    if ($LASTEXITCODE -eq 0) {
      $m = ($out | Select-String -Pattern 'https?://github\.com/.+?/pull/\d+' | Select-Object -First 1)
      if ($m) { $createdUrl = $m.Matches.Value; $used = "gh" }
    } else {
      Write-Warning "gh pr create hata verdi: $out"
    }
  } catch {
    Write-Warning "gh pr create çalışmadı: $($_.Exception.Message)"
  }
}

if (-not $createdUrl) {
  $token = $env:GITHUB_TOKEN
  if ($token) {
    $bodyObj = @{
      title = $title
      head  = $Branch
      base  = $BaseBranch
      body  = $body
    }
    $json = $bodyObj | ConvertTo-Json -Depth 5
    $uri  = "https://api.github.com/repos/$repoSlug/pulls"

    $headers = @{
      "Accept"        = "application/vnd.github+json"
      "Authorization" = "token $token"
      "X-GitHub-Api-Version" = "2022-11-28"
      "User-Agent"    = "ps-open-pr"
    }
    try {
      $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $json
      if ($resp.html_url) { $createdUrl = $resp.html_url; $used = "rest" }
    } catch [System.Net.WebException] {
      Show-GitHubErrorBody $_.Exception
      Write-Warning "REST ile PR açma denemesi hata verdi."
    }
  } else {
    Write-Warning "Ne 'gh' komutu başarılı ne de GITHUB_TOKEN tanımlı. PR otomatik açılamadı (pipeline kesilmedi)."
  }
}

if ($createdUrl) {
  Write-Host "[pr] Açıldı ($used) → $createdUrl" -ForegroundColor Green
  . (Join-Path $RepoRoot $StateTools)
  Advance-Pipeline -ToStage "await_review" -Hint "PR açıldı: $createdUrl"
} else {
  Write-Host "[pr] PR açılamadı; stage değiştirilmedi." -ForegroundColor Yellow
}


