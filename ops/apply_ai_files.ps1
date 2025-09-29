param(
  [string]$RepoRoot = ".",
  [string]$InboxDir = "ai_inbox",
  [string]$StateTools = "ops/state_tools.ps1",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Ensure-Module {
  param([string]$Path)
  if (-not (Test-Path $Path)) { throw "Gerekli script bulunamadı: $Path" }
  . $Path
}
function Normalize-TargetPath {
  param([string]$InboxFile)
  $rel = (Resolve-Path -LiteralPath $InboxFile).Path.Substring((Resolve-Path -LiteralPath $InboxDir).Path.Length).TrimStart('\','/')
  $rel = $rel -replace '^[\\/]+',''
  if ($rel.ToLower().EndsWith(".txt")) { $rel = $rel.Substring(0, $rel.Length-4) }
  $rel = $rel -replace '^(root[\\/])',''
  return $rel
}
function New-Directory {
  param([string]$Path)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

Ensure-Module -Path (Join-Path $RepoRoot $StateTools)

$inboxFull = Join-Path $RepoRoot $InboxDir
if (-not (Test-Path $inboxFull)) {
  Write-Host "[apply] Inbox klasörü yok: $InboxDir (atlandı)" -ForegroundColor Yellow
  exit 0
}

$changed = @(); $deleted = @(); $skipped = @()
$txts = Get-ChildItem $inboxFull -Recurse -File -Filter *.txt
if (-not $txts) { Write-Host "[apply] Inbox boş." -ForegroundColor Yellow; exit 0 }

foreach ($f in $txts) {
  $targetRel = Normalize-TargetPath -InboxFile $f.FullName
  $targetAbs = Join-Path $RepoRoot $targetRel
  $raw = Get-Content -LiteralPath $f.FullName -Raw

  if ($raw -match '^\s*#\s*DELETE\s*$') {
    if (Test-Path $targetAbs) {
      if ($DryRun) { Write-Host "[DRY] DELETE $targetRel" -ForegroundColor Yellow }
      else { Remove-Item -LiteralPath $targetAbs -Force; $deleted += $targetRel }
    } else { $skipped += "$targetRel (zaten yok)" }
    continue
  }

  if ([string]::IsNullOrWhiteSpace($raw)) { $skipped += "$targetRel (boş içerik/no-op)"; continue }

  if ($DryRun) { Write-Host "[DRY] WRITE $targetRel" -ForegroundColor Cyan }
  else {
    if (Test-Path $targetAbs) { Copy-Item -LiteralPath $targetAbs "$targetAbs.bak" -Force -ErrorAction SilentlyContinue }
    New-Directory -Path $targetAbs
    [IO.File]::WriteAllText($targetAbs, $raw, [Text.UTF8Encoding]::new($false))
    $changed += $targetRel
  }
}

if (-not $DryRun) {
  foreach ($p in $changed) { Add-PendingAction -Id ("APPLY-" + [Guid]::NewGuid().ToString("N")) -Type "FILE_WRITE"  -Detail $p -DueStage "" }
  foreach ($p in $deleted) { Add-PendingAction -Id ("APPLY-" + [Guid]::NewGuid().ToString("N")) -Type "FILE_DELETE" -Detail $p -DueStage "" }
}

Write-Host "`n=== APPLY SUMMARY ===" -ForegroundColor Green
"{0,-10} {1}" -f "Changed:", ($changed.Count)
"{0,-10} {1}" -f "Deleted:", ($deleted.Count)
"{0,-10} {1}" -f "Skipped:", ($skipped.Count)
if ($changed) { "`n-- Changed files --"; $changed | ForEach-Object { "  - $_" } }
if ($deleted) { "`n-- Deleted files --"; $deleted | ForEach-Object { "  - $_" } }
if ($skipped) { "`n-- Skipped --"; $skipped | ForEach-Object { "  - $_" } }
