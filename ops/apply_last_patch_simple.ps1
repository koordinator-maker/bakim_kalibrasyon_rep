# apply_last_patch_simple.ps1  (PS 5.1)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Settings (keep ASCII)
$WHITELIST = @(
  'app\', 'apps\', 'src\', 'backend\', 'frontend\',
  'bakim_kalibrasyon\',
  'templates\', 'static\', 'public\', 'assets\',
  'tests\', 'test\',
  'scripts\', 'tools\',
  'manage.py', 'package.json', 'package-lock.json', 'requirements.txt'
)
$BLACKLIST = @(
  '.git\', '.github\', '.gitignore',
  '_otokodlama\', 'venv\', 'node_modules\',
  'playwright-report\', 'dist\', 'build\'
)
$MAXFILES = 200
$MAXBYTES = 5242880

function New-U8Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ return }
  if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Norm([string]$p){ return ($p -replace '[\\/]+','\') }
function StartsWithCI([string]$a,[string]$b){ return $a.StartsWith($b, [StringComparison]::OrdinalIgnoreCase) }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$inbox    = (Resolve-Path (Join-Path $PSScriptRoot '..\_otokodlama\inbox')).Path
$outDir   = (Join-Path $repoRoot '_otokodlama\out'); New-U8Dir $outDir
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'

$zip = Get-ChildItem -Path $inbox -Filter 'patch_*.zip' -File -EA SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1 -Expand FullName
if(-not $zip){ Write-Warning "No patch_*.zip in inbox."; return }

$temp = Join-Path $env:TEMP ("patch_" + [IO.Path]::GetFileNameWithoutExtension($zip) + "_" + $ts)
New-U8Dir $temp
try{
  Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force

  $changed = New-Object System.Collections.Generic.List[string]
  $skipped = New-Object System.Collections.Generic.List[string]

  $files = Get-ChildItem -Path $temp -Recurse -File
  $count = 0
  foreach($f in $files){
    if($count -ge $MAXFILES){ $skipped.Add("[LIMIT] $($f.FullName)"); break }
    $count++

    $rel = (Resolve-Path $f.FullName).Path.Substring((Resolve-Path $temp).Path.Length).TrimStart('\','/')
    $rel = Norm $rel
    if([string]::IsNullOrWhiteSpace($rel)){ continue }

    # Whitelist / blacklist
    $allow = $false
    foreach($w in $WHITELIST){
      $wN = Norm $w
      if($wN.EndsWith('\')){
        if(StartsWithCI $rel $wN){ $allow = $true; break }
      } else {
        if($rel.Equals($wN, [StringComparison]::OrdinalIgnoreCase)){ $allow = $true; break }
      }
    }
    if(-not $allow){ $skipped.Add("[NOT-ALLOWED] $rel"); continue }

    $deny = $false
    foreach($b in $BLACKLIST){
      $bN = Norm $b
      if($bN.EndsWith('\')){
        if(StartsWithCI $rel $bN){ $deny = $true; break }
      } else {
        if($rel.Equals($bN, [StringComparison]::OrdinalIgnoreCase)){ $deny = $true; break }
      }
    }
    if($deny){ $skipped.Add("[BLACKLIST] $rel"); continue }

    if($f.Length -gt [int64]$MAXBYTES){ $skipped.Add("[TOO-LARGE] $rel ($($f.Length) bytes)"); continue }

    $dest = Join-Path $repoRoot $rel
    $destDir = [IO.Path]::GetDirectoryName($dest)
    if($destDir){ New-U8Dir $destDir }

    # backup
    $bakRoot = Join-Path $outDir ("backup_simple_" + [IO.Path]::GetFileNameWithoutExtension($zip) + "_" + $ts)
    New-U8Dir $bakRoot
    if(Test-Path $dest){
      $bakPath = Join-Path $bakRoot $rel
      $bakDir  = [IO.Path]::GetDirectoryName($bakPath)
      if($bakDir){ New-U8Dir $bakDir }
      Copy-Item -LiteralPath $dest -Destination $bakPath -Force
    }

    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    $changed.Add($rel) | Out-Null
  }

  $logChanged = Join-Path $outDir ("changed_simple_" + [IO.Path]::GetFileName($zip) + "_" + $ts + ".txt")
  $logSkipped = Join-Path $outDir ("skipped_simple_" + [IO.Path]::GetFileName($zip) + "_" + $ts + ".txt")
  if($changed.Count -gt 0){ $changed | Out-File -Encoding UTF8 -FilePath $logChanged }
  if($skipped.Count -gt 0){ $skipped | Out-File -Encoding UTF8 -FilePath $logSkipped }

  Write-Host "PATCH APPLIED (simple)"
  Write-Host ("  zip      : {0}" -f $zip)
  Write-Host ("  applied  : {0}" -f $changed.Count)
  Write-Host ("  skipped  : {0}" -f $skipped.Count)
  Write-Host ("  backup   : {0}" -f $bakRoot)
  if(Test-Path $logChanged){ Write-Host ("  changed  : {0}" -f $logChanged) }
  if(Test-Path $logSkipped){ Write-Host ("  skippedL : {0}" -f $logSkipped) }
}
finally{
  if(Test-Path $temp){ Remove-Item -LiteralPath $temp -Recurse -Force -EA SilentlyContinue }
}