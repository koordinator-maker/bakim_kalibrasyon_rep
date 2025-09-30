param(
  [string]$RepoRoot = ".",
  [string]$Branch   = "main",
  [string]$AddSpec  = ".",
  [string]$Message  = "[auto] apply files + update state",
  [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$dirty = & git status --porcelain
if (-not $dirty) { Write-Host "[git] Çalışma alanı temiz; commit/push atlandı." -ForegroundColor Yellow; exit 0 }

& git add $AddSpec
try { & git commit -m $Message } catch { Write-Host "[git] Commit başarısız: $($_.Exception.Message)" -ForegroundColor Red; exit 2 }

if (-not $NoPush) {
  try { & git push origin $Branch } catch { Write-Host "[git] Push başarısız: $($_.Exception.Message)" -ForegroundColor Red; exit 3 }
  Write-Host "[git] Pushed to origin/$Branch" -ForegroundColor Green
} else {
  Write-Host "[git] --NoPush seçildi, push atlandı." -ForegroundColor Yellow
}

