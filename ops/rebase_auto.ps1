param(
  [string]$Branch,
  [int]$PrNumber = 0
)

$ErrorActionPreference = 'Stop'

function Abort-StaleRebase {
  if (Test-Path ".git\rebase-apply" -or (Test-Path ".git\rebase-merge")) {
    git rebase --abort | Out-Null
  }
}

function Solve-Bumper {
  New-Item -ItemType Directory -Force ".github" | Out-Null
  "trigger $(Get-Date -Format s)" | Set-Content ".github\pr-bumper.md"
  git add ".github\pr-bumper.md" | Out-Null
}

# Branch boşsa PR'dan çöz, o da yoksa aktif dal
if (-not $Branch) {
  if ($PrNumber -gt 0) {
    $Branch = gh pr view $PrNumber --json headRefName --jq .headRefName
  }
  if (-not $Branch) {
    $Branch = (git rev-parse --abbrev-ref HEAD)
    if (-not $Branch -or $Branch -eq 'HEAD') {
      throw "Branch bulunamadı: -Branch ver ya da -PrNumber ile PR'dan çözelim."
    }
  }
}

function Rebase-Or-Merge([string]$branch) {
  git fetch origin    | Out-Null
  git checkout $branch| Out-Null

  # 1) REBASE dene (editor'suz)
  git -c core.editor=true -c sequence.editor=true rebase origin/main
  if ($LASTEXITCODE -eq 0) { return }

  Write-Warning "Rebase başarısız → rebase abort + MERGE fallback'a geçiyorum."
  git rebase --abort 2>$null | Out-Null

  # 2) MERGE (editor'suz, auto-msg)
  git merge --no-edit origin/main
  if ($LASTEXITCODE -ne 0) {
    # en sık çatışma: pr-bumper.md → üzerine yazıp ekle
    if (Test-Path ".github\pr-bumper.md") {
      Write-Host "[merge] bumper conflict → auto-fix" -ForegroundColor Yellow
      Solve-Bumper
      # başka dosya çatışması var mı?
      $confLeft = git ls-files -u
      if ($confLeft) {
        throw "Bumper dışı merge çatışmaları var; manuel müdahale gerekir."
      }
      git commit --no-edit
      if ($LASTEXITCODE -ne 0) { throw "Merge commit atılamadı." }
    } else {
      throw "Merge başarısız ve bumper bulunamadı; manuel çözüm gerek."
    }
  }

  return
}

function Auto-Merge-Pr([int]$pr) { if ($pr -gt 0) { gh pr merge $pr --squash --auto } }

Abort-StaleRebase
Rebase-Or-Merge $Branch
git push --force-with-lease origin $Branch
Auto-Merge-Pr $PrNumber

Write-Host "[done] $Branch güncellendi ve push edildi." -ForegroundColor Green
if ($PrNumber -gt 0) { Write-Host "[note] PR #$PrNumber auto-merge açık; koşullar tamamlanınca birleşir." -ForegroundColor Yellow }
