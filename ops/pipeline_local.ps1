param(
  [string]$BaseUrl     = "http://127.0.0.1:8010",
  [string]$JobsCsv     = "ops/ui_jobs.csv",
  [string]$BaselineDir = "targets\reference",
  [string]$AlertsDir   = "_otokodlama\alerts",
  [string]$StateTools  = "ops/state_tools.ps1",
  [switch]$NoGitPush
)

$ErrorActionPreference = "Stop"

# 1) AI patch'leri uygula (varsa)
powershell -ExecutionPolicy Bypass -File "ops/apply_ai_files.ps1" -RepoRoot "." -InboxDir "ai_inbox" -StateTools $StateTools | Out-Host

# 2) UI testlerini koştur + state güncelle
powershell -ExecutionPolicy Bypass -File "ops/run_suite.ps1" -BaseUrl $BaseUrl -JobsCsv $JobsCsv -BaselineDir $BaselineDir -AlertsDir $AlertsDir -StateTools $StateTools | Out-Host

# 3) Değişiklikleri commit/push
if ($NoGitPush) {
  powershell -ExecutionPolicy Bypass -File "ops/git_ops.ps1" -RepoRoot "." -Branch "main" -AddSpec "." -Message "[auto] ai apply + ui validate + state" -NoPush | Out-Host
} else {
  powershell -ExecutionPolicy Bypass -File "ops/git_ops.ps1" -RepoRoot "." -Branch "main" -AddSpec "." -Message "[auto] ai apply + ui validate + state" | Out-Host
}

Write-Host "`n[pipeline] DONE." -ForegroundColor Green

