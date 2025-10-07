param(
  [string]$Branch = "ci/e2e-i18n-setup-fixes",
  [string]$WorkflowFile = "e2e.yml",
  [string]$OutRoot = "ci-artifacts"
)

$ErrorActionPreference = "Stop"

# owner/repo
$repo = (git config --get remote.origin.url).Replace("https://github.com/","").Replace(".git","")
if (-not $repo) { throw "Git remote.origin.url bulunamadı." }

# 1) Workflow'u tetikle
gh workflow run $WorkflowFile --ref $Branch
if (-not $?) { throw "Workflow dispatch gönderilemedi." }

# 2) Son run ID'yi etkileşimsiz al (yalnızca bu workflow + branch)
$runId = gh run list --workflow $WorkflowFile --branch $Branch --json databaseId `
  -q '.[0].databaseId' --limit 1 | Out-String
$runId = $runId.Trim()
if (-not $runId) { throw "Run ID alınamadı." }
Write-Host "Run ID: $runId" -ForegroundColor Cyan

# 3) Bitene kadar izle
gh run watch $runId --exit-status
if (-not $?) { throw "Run failed." }

# 4) Artifact'ları zaman damgalı klasöre indir (çakışma olmaz)
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = Join-Path $OutRoot $stamp
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# HTML rapor (varsa)
gh run download $runId --name "playwright-report" -D $outDir 2>$null
# Trace/video (varsa)
gh run download $runId --name "traces" -D $outDir 2>$null

Write-Host "`n[OK] Raporlar indirildi: $outDir" -ForegroundColor Green

# Windows'ta raporu aç
$index = Join-Path $outDir "index.html"
if (Test-Path $index) { Start-Process $index }