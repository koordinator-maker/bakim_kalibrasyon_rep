# Rev: 2025-09-30 22:09 r6

param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8010,
  [switch]$StartServer = $true,
  [string]$FlowsFilter = "*",
  [switch]$LinkSmoke = $true,
  [int]$SmokeDepth = 1,
  [int]$SmokeLimit = 200,
  [int]$TimeoutMs = 20000,
  [string]$BaseUrl = "",
  [string]$SoundProfile = "notify",
  [string]$SoundFile = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== DEBUG RUNNER START ===" -ForegroundColor Cyan
Write-Host ("PWD: " + (Get-Location)) -ForegroundColor DarkCyan
Write-Host ("PSVersion: " + $PSVersionTable.PSVersion) -ForegroundColor DarkCyan

# repo root
$root = & git rev-parse --show-toplevel 2>$null
if (-not $root) { throw "Git repo not found. Run from inside repository." }
Set-Location $root
Write-Host ("Repo root: " + $root) -ForegroundColor DarkCyan

# Unblock scripts
Get-ChildItem tools\*.ps1,ops\*.ps1 -ErrorAction SilentlyContinue | Unblock-File

# default BaseUrl
if (-not $BaseUrl) { $BaseUrl = "http://${BindHost}:${Port}" }
Write-Host ("BaseUrl: " + $BaseUrl) -ForegroundColor DarkCyan

# Sanity checks
@(
  "tools\pipeline_and_next.ps1",
  "ops\run_backlog_sound.ps1",
  "tools\sound.ps1"
) | ForEach-Object {
  Write-Host ("Check: " + $_ + " -> " + (Test-Path $_)) -ForegroundColor DarkGray
}

# Call main pipeline
& "tools\pipeline_and_next.ps1" `
  -BindHost $BindHost -Port $Port -StartServer:$StartServer `
  -FlowsFilter $FlowsFilter -LinkSmoke:$LinkSmoke -SmokeDepth $SmokeDepth -SmokeLimit $SmokeLimit `
  -TimeoutMs $TimeoutMs -BaseUrl $BaseUrl -SoundProfile $SoundProfile -SoundFile $SoundFile

Write-Host "=== DEBUG RUNNER END ===" -ForegroundColor Cyan

