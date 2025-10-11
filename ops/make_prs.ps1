Rev: 2025-09-30 19:21 r1
param(
  [string]$PlanJson = "plan/tasks.json",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PlanJson)) { throw "Plan yok: $PlanJson" }

# main’i referans al
git fetch origin | Out-Null

$tasks = Get-Content $PlanJson -Raw | ConvertFrom-Json
foreach ($t in $tasks) {
  $branch = $t.branch_name
  if (-not $branch) { Write-Warning "Branch yok: $($t.id)"; continue }

  # remote’ta var mı?
  $remote = git ls-remote --heads origin $branch
  if ($remote) { Write-Host "(skip) zaten var: $branch" -ForegroundColor DarkYellow; continue }

  if (-not $DryRun) {
    git switch -c $branch origin/main | Out-Null

    New-Item -ItemType Directory -Force ".github" | Out-Null
    "task: $($t.id) - $($t.title)" | Set-Content -Encoding UTF8 ".github\pr-bumper.md"
    git add ".github\pr-bumper.md"
    git commit -m "auto($($t.id)): $($t.title) [bump]" | Out-Null
    git push -u origin $branch | Out-Null
  }

  # PR body
  $ac = ""
  if ($t.acceptance_criteria) {
    $ac = "Acceptance Criteria:`n" + ($t.acceptance_criteria | ForEach-Object { "- $_" }) -join "`n"
  }
  $body = @"
Area: `$($t.area)`
Type: `$($t.type)` | Priority: `$($t.priority)` | Size: `$($t.size)`

$($t.description)

$ac
"@

  $title = "auto: $($t.id) $($t.title)"
  $prUrl = gh pr create -t $title -b $body -B main -H $branch
  if ($LASTEXITCODE -ne 0) { Write-Warning "PR açılamadı: $branch"; continue }

  # etiketler
  if ($t.labels) {
    foreach ($lbl in $t.labels) { gh pr edit $prUrl --add-label $lbl | Out-Null }
  }

  # otomatik merge (koşullar sağlanınca)
  gh pr merge $prUrl --squash --auto | Out-Null

  Write-Host "[ok] PR hazır: $prUrl" -ForegroundColor Green

  # ana dala geri
  if (-not $DryRun) {
    git switch -C main origin/main | Out-Null
  }
}
