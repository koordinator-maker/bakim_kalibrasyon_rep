Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if (-not $env:BASE_URL)   { $env:BASE_URL   = "http://127.0.0.1:8010" }
if (-not $env:ADMIN_USER) { $env:ADMIN_USER = "admin" }
if (-not $env:ADMIN_PASS) { $env:ADMIN_PASS = "admin123!" }

npx playwright test --project=chromium --reporter=line,html,blob

New-Item -ItemType Directory -Force _otokodlama\out | Out-Null
npx playwright merge-reports --reporter=json blob-report > _otokodlama/out/pw.json

powershell -File tools/post_pr_summary.ps1