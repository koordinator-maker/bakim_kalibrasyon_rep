# PS 5.1 compatible, ASCII only, no exit
# Safe patch apply: zip-slip guard, whitelist/blacklist, size/entry limits, backups, change log

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- AYARLAR (gerekirse güncelle) ----
$global:PATCH_WRITE_WHITELIST = @(
  'app\', 'apps\', 'src\', 'backend\', 'frontend\',
  'bakim_kalibrasyon\',
  'templates\', 'static\', 'public\', 'assets\',
  'tests\', 'test\',
  'scripts\', 'tools\',
  'manage.py', 'package.json', 'package-lock.json', 'requirements.txt'
)

$global:PATCH_WRITE_BLACKLIST = @(
  '.git\', '.github\', '.gitignore',
  '_otokodlama\', 'venv\', 'node_modules\',
  'playwright-report\', 'dist\', 'build\'
)

$global:PATCH_MAX_FILES = 200
$global:PATCH_MAX_FILE_BYTES = 5242880  # 5MB

function New-U8Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ return }
  if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

function Join-Normalized([string]$base,[string]$rel){
  $r = ($rel -replace '[\\/]+','\').Trim()
  while($r.StartsWith('..\') -or $r.StartsWith('/') -or $r.StartsWith('\')){
    if($r.StartsWith('..\')){ $r = $r.Substring(3) }
    elseif($r.StartsWith('/')){ $r = $r.Substring(1) }
    elseif($r.StartsWith('\')){ $r = $r.Substring(1) }
    else { break }
  }
  return (Join-Path $base $r)
}

function Get-RelPath([string]$root,[string]$full){
  $rootFull = [IO.Path]::GetFullPath($root)
  $fullFull = [IO.Path]::GetFullPath($full)
  if($fullFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)){
    $rel = $fullFull.Substring($rootFull.Length)
    if($rel.StartsWith('\')){ $rel = $rel.Substring(1) }
    return $rel
  }
  return $full
}

function Is-Under([string]$root,[string]$full){
  $rootFull = [IO.Path]::GetFullPath($root)
  $fullFull = [IO.Path]::GetFullPath($full)
  return $fullFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)
}

function Is-Whitelisted([string]$rel){
  $r = ($rel -replace '[\\/]+','\')
  foreach($w in $global:PATCH_WRITE_WHITELIST){
    $p = ($w -replace '[\\/]+','\')
    if($p.EndsWith('\')){ if($r.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)){ return $true } }
    else { if($r.Equals($p, [StringComparison]::OrdinalIgnoreCase)){ return $true } }
  }
  return $false
}

function Is-Blacklisted([string]$rel){
  $r = ($rel -replace '[\\/]+','\')
  foreach($b in $global:PATCH_WRITE_BLACKLIST){
    $p = ($b -replace '[\\/]+','\')
    if($p.EndsWith('\')){ if($r.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)){ return $true } }
    else { if($r.Equals($p, [StringComparison]::OrdinalIgnoreCase)){ return $true } }
  }
  return $false
}

function Apply-PatchZip {
  param(
    [Parameter(Mandatory=$true)][string]$ZipPath,
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [string]$OutDir = "_otokodlama\out",
    [switch]$WhatIf
  )
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  if(-not (Test-Path $ZipPath)){ throw "Patch ZIP not found: $ZipPath" }
  if(-not (Test-Path $RepoRoot)){ throw "Repo root not found: $RepoRoot" }

  New-U8Dir $OutDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $logChanged = Join-Path $OutDir ("changed_" + (Split-Path -Leaf $ZipPath) + "_" + $ts + ".txt")
  $logSkipped = Join-Path $OutDir ("skipped_" + (Split-Path -Leaf $ZipPath) + "_" + $ts + ".txt")
  $bakRoot    = Join-Path $OutDir ("backup_" + (Split-Path -Leaf $ZipPath) + "_" + $ts)
  New-U8Dir $bakRoot

  # --- FIX: PS 5.1 için gerekli iki assembly'i yükle ---
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem

  $repoFull = [IO.Path]::GetFullPath($RepoRoot)
  $changed = New-Object System.Collections.Generic.List[string]
  $skipped = New-Object System.Collections.Generic.List[string]
  $appliedCount = 0
  $skippedCount = 0

  # --- FIX: Zip'i ZipFile::OpenRead ile aç ---
  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try{
    $entries = $zip.Entries
    $limit = $entries.Count
    if($limit -gt $global:PATCH_MAX_FILES){ $limit = $global:PATCH_MAX_FILES }

    for($i=0; $i -lt $limit; $i++){
      $e = $entries[$i]
      $nameRaw = $e.FullName
      if([string]::IsNullOrWhiteSpace($nameRaw)){ continue }
      if($nameRaw.EndsWith('/') -or $nameRaw.EndsWith('\')){ continue }

      $rel = ($nameRaw -replace '[\\/]+','\').Trim()
      while($rel.StartsWith('..\') -or $rel.StartsWith('/') -or $rel.StartsWith('\')){
        if($rel.StartsWith('..\')){ $rel = $rel.Substring(3) }
        elseif($rel.StartsWith('/')){ $rel = $rel.Substring(1) }
        elseif($rel.StartsWith('\')){ $rel = $rel.Substring(1) }
        else { break }
      }
      if([string]::IsNullOrWhiteSpace($rel)){ continue }

      $dest = Join-Normalized $repoFull $rel
      if(-not (Is-Under $repoFull $dest)){
        $skipped.Add("[TRAVERSAL] $rel") | Out-Null; $skippedCount++; continue
      }

      $relRepo = Get-RelPath $repoFull $dest
      if(Is-Blacklisted $relRepo){ $skipped.Add("[BLACKLIST] $rel") | Out-Null; $skippedCount++; continue }
      if(-not (Is-Whitelisted $relRepo)){ $skipped.Add("[NOT-ALLOWED] $rel") | Out-Null; $skippedCount++; continue }

      if($e.Length -gt [int64]$global:PATCH_MAX_FILE_BYTES){
        $skipped.Add("[TOO-LARGE] $rel ($($e.Length) bytes)") | Out-Null; $skippedCount++; continue
      }

      $destDir = [IO.Path]::GetDirectoryName($dest)
      if($destDir){ New-U8Dir $destDir }

      if(Test-Path $dest){
        $bakPath = Join-Path $bakRoot ($relRepo -replace '[\\/]+','\')
        $bakDir  = [IO.Path]::GetDirectoryName($bakPath)
        if($bakDir){ New-U8Dir $bakDir }
        Copy-Item -LiteralPath $dest -Destination $bakPath -Force
      }

      if($WhatIf){
        $changed.Add("[WHATIF] $rel -> $dest") | Out-Null; $appliedCount++; continue
      }

      $inStream  = $e.Open()
      try{
        $outStream = [IO.File]::Open($dest, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try{
          $buf = New-Object byte[] 81920
          while($true){
            $read = $inStream.Read($buf, 0, $buf.Length)
            if($read -le 0){ break }
            $outStream.Write($buf, 0, $read)
          }
        } finally { $outStream.Dispose() }
      } finally { $inStream.Dispose() }

      $changed.Add($rel) | Out-Null
      $appliedCount++
    }
  } finally {
    if($zip){ $zip.Dispose() }
  }

  if($changed.Count -gt 0){ $changed | Out-File -FilePath $logChanged -Encoding UTF8 }
  if($skipped.Count -gt 0){ $skipped | Out-File -FilePath $logSkipped -Encoding UTF8 }

  return [pscustomobject]@{
    zip            = (Resolve-Path $ZipPath).Path
    repo           = (Resolve-Path $RepoRoot).Path
    appliedCount   = $appliedCount
    skippedCount   = $skippedCount
    changedLog     = (if(Test-Path $logChanged){ (Resolve-Path $logChanged).Path } else { $null })
    skippedLog     = (if(Test-Path $logSkipped){ (Resolve-Path $logSkipped).Path } else { $null })
    backupRoot     = (Resolve-Path $bakRoot).Path
    whitelist      = $global:PATCH_WRITE_WHITELIST
    blacklist      = $global:PATCH_WRITE_BLACKLIST
    maxFiles       = $global:PATCH_MAX_FILES
    maxFileBytes   = [int64]$global:PATCH_MAX_FILE_BYTES
  }
}