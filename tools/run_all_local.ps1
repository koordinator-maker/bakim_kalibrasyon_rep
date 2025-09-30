# Rev: 2025-09-30 rT3
param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8010,
  [string]$BaseUrl = "",
  [string]$Filter = "*",
  [switch]$LinkSmoke,
  [int]$SmokeDepth = 1,
  [int]$SmokeLimit = 200,
  [int]$TimeoutMs = 20000,
  [string]$SoundProfile = "notify",
  [string]$SoundFile = ""
)
$ErrorActionPreference = "Stop"

# repo root
$root = & git rev-parse --show-toplevel 2>$null
if (-not $root) { throw "Git repo not found. Run from inside the repository." }
Set-Location $root

# default BaseUrl
if (-not $BaseUrl -or $BaseUrl -eq "") { $BaseUrl = "http://${BindHost}:${Port}" }

Write-Host ("[info] BaseUrl: {0}" -f $BaseUrl) -ForegroundColor Cyan

# 1) generate flows
powershell -ExecutionPolicy Bypass -File ops\gen_from_backlog.ps1
if ($LASTEXITCODE -ne 0) { throw "gen_from_backlog failed." }

# 2) build args for run_backlog_sound.ps1 (switch added only if True)
$argList = @(
  '-ExecutionPolicy','Bypass',
  '-File','ops\run_backlog_sound.ps1',
  '-Filter', $Filter,
  '-BaseUrl', $BaseUrl,
  '-SmokeDepth', ([string]$SmokeDepth),
  '-SmokeLimit', ([string]$SmokeLimit),
  '-TimeoutMs', ([string]$TimeoutMs),
  '-SoundProfile', $SoundProfile
)
if ($LinkSmoke) { $argList += '-LinkSmoke' }
if ($SoundFile -and $SoundFile.Trim().Length -gt 0) { $argList += @('-SoundFile', $SoundFile) }

# 3) run flows
& powershell @argList
exit $LASTEXITCODE
