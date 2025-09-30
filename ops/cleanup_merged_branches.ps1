$ErrorActionPreference = "Stop"
cmd /c "git rebase --abort 1>nul 2>nul"
cmd /c "git merge  --abort 1>nul 2>nul"
cmd /c "git cherry-pick --abort 1>nul 2>nul"

git fetch origin | Out-Null
git switch -C main origin/main | Out-Null
git worktree prune

$merged = gh pr list --state closed --json number,mergedAt,headRefName `
  --jq '.[] | select(.mergedAt!=null) | [.number,.headRefName] | @tsv'

if ($merged) {
  foreach ($ln in ($merged -split "`n")) {
    $p = $ln -split "`t"; $n = [int]$p[0]; $br = $p[1]

    if (git ls-remote --heads origin $br) {
      $null = cmd /c "git push origin --delete $br 1>nul 2>nul"
      Write-Host "Remote silindi: $br (PR #$n)"
    }

    $wt = (git worktree list --porcelain) -join "`n" `
      | Select-String "branch refs/heads/$br" -Context 1,1 `
      | ForEach-Object { $_.Context.PreContext + $_.Line + $_.Context.PostContext } `
      | Select-String "^worktree " | ForEach-Object { ($_ -split '\s+',2)[1] }
    foreach ($p2 in $wt) { git worktree remove --force $p2 | Out-Null }

    if (git branch --list $br) {
      git branch -D $br | Out-Null
      Write-Host "Local silindi : $br (PR #$n)"
    }
  }
} else {
  Write-Host "Silinecek merge edilmiş PR dalı yok."
}
