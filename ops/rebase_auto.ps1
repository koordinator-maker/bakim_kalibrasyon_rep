param(
   [string]$Branch,
   [int]$PrNumber = 0
)

$ErrorActionPreference = 'Stop'

function Abort-StaleOps {
   git rebase --abort 2>$null | Out-Null
   git merge  --abort 2>$null | Out-Null
}

function Solve-Bumper {
   New-Item -ItemType Directory -Force ".github" | Out-Null
   "trigger $(Get-Date -Format s)" | Set-Content ".github\pr-bumper.md"
   git add ".github\pr-bumper.md" | Out-Null
}

function Get-Conflicts {
   # Çatışan dosyaları tekil listele
   (git ls-files -u) -split "`n" |
     Where-Object { $_ -ne "" } |
     ForEach-Object { ($_ -split "\s+")[3] } |
     Sort-Object -Unique
}

# --- Branch'ı akıllı şekilde çöz ---
if (-not $Branch) {
   if ($PrNumber -gt 0) {
     $Branch = gh pr view $PrNumber --json headRefName --jq .headRefName
     if (-not $Branch) { throw "PR #$PrNumber bulunamadı/kapalı. -Branch vererek deneyin." }
   } else {
     $Branch = gh pr list --state open --limit 1 --json headRefName --jq '.[0].headRefName' 2>$null
     if (-not $Branch) {
       $Branch = (git rev-parse --abbrev-ref HEAD)
       if (-not $Branch -or $Branch -eq 'HEAD') { throw "Açık PR yok ve aktif dal çözülemedi. -Branch ya da -PrNumber verin." }
     }
   }
}

function Rebase-Or-Merge([string]$branch) {
   git fetch origin | Out-Null
   git checkout $branch | Out-Null

   # 1) REBASE (editörsüz olsun diye boş mesajla commit atmaya zorlamayacağız; direkt deneyip düşersek merge)
   git -c core.editor=true -c sequence.editor=true rebase origin/main
   if ($LASTEXITCODE -eq 0 -and -not (Test-Path ".git\rebase-apply") -and -not (Test-Path ".git\rebase-merge")) {
     return  # başarılı rebase
   }

   Write-Warning "Rebase tamamlanamadı → MERGE fallback'a geçiyorum."
   git rebase --abort 2>$null | Out-Null

   # 2) MERGE (editor açmadan, no-edit ile)
   git merge --no-edit origin/main
   if ($LASTEXITCODE -ne 0) {
     # Bumper'ı tazele
     Solve-Bumper

     # Kalan bütün çatışmalar --> OURS (mevcut dal)
     $conf = Get-Conflicts
     if ($conf) {
       foreach ($p in $conf) {
         if ($p -ne ".github/pr-bumper.md") {
           git checkout --ours -- "$p"
           git add -- "$p"
         }
       }
     }

     # Her şey eklendiyse commitle
     git commit --no-edit
     if ($LASTEXITCODE -ne 0) { throw "Merge commit atılamadı. Kalan çatışmalar olabilir." }
   }
}

# --- Çalıştır ---
Abort-StaleOps
Rebase-Or-Merge $Branch
git push --force-with-lease origin $Branch

if ($PrNumber -gt 0) { gh pr merge $PrNumber --squash --auto }

Write-Host "[done] $Branch güncellendi ve push edildi." -ForegroundColor Green
if ($PrNumber -gt 0) { Write-Host "[note] PR #$PrNumber auto-merge açık; koşullar tamamlanınca birleşir." -ForegroundColor Yellow }
