Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Save-Utf8NoBom([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = [IO.Path]::GetDirectoryName($Path)
  if ($dir) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
  [IO.File]::WriteAllText($Path,$Text,$enc)
}

function Ensure-ZipSupport {
  $asm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.IO.Compression.FileSystem' }
  if (-not $asm) {
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
  }
}

function Apply-PatchZip {
  param(
    [Parameter(Mandatory=$true)][string]$ZipPath,
    [Parameter(Mandatory=$true)][string]$RepoRoot
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Zip not found: $ZipPath" }
  if (-not (Test-Path -LiteralPath $RepoRoot)) { throw "Repo root not found: $RepoRoot" }

  Ensure-ZipSupport

  $stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backupRoot = Join-Path $RepoRoot ("_otokodlama\backup\patch_" + [IO.Path]::GetFileNameWithoutExtension($ZipPath) + "_" + $stamp)
  $outDir     = Join-Path $RepoRoot "_otokodlama\out"
  [IO.Directory]::CreateDirectory($backupRoot) | Out-Null
  [IO.Directory]::CreateDirectory($outDir)     | Out-Null

  $changed       = New-Object System.Collections.Generic.List[string]
  $skipped       = New-Object System.Collections.Generic.List[string]
  $appliedCount  = 0
  $skippedCount  = 0

  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    foreach($entry in $zip.Entries){
      $name = $entry.FullName
      if ([string]::IsNullOrWhiteSpace($name)) { continue }
      if ($name.EndsWith("/")) { continue } # directory

      $rel = $name -replace '/', '\'
      if ($rel -match '^\.\.' -or $rel -match '^[\\/]' ) { $skipped.Add($rel); $skippedCount++; continue }

      $target = Join-Path $RepoRoot $rel
      $tDir   = [IO.Path]::GetDirectoryName($target)
      if ($tDir) { [IO.Directory]::CreateDirectory($tDir) | Out-Null }

      if (Test-Path -LiteralPath $target) {
        $bakPath = Join-Path $backupRoot $rel
        $bakDir  = [IO.Path]::GetDirectoryName($bakPath)
        if ($bakDir) { [IO.Directory]::CreateDirectory($bakDir) | Out-Null }
        Copy-Item -LiteralPath $target -Destination $bakPath -Force
      }

      $stream = $entry.Open()
      try {
        $fs = [IO.File]::Open($target, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
          $stream.CopyTo($fs)
        } finally { $fs.Dispose() }
      } finally { $stream.Dispose() }

      $changed.Add($rel)
      $appliedCount++
    }
  } finally {
    $zip.Dispose()
  }

  $prefix       = "patch_" + [IO.Path]::GetFileNameWithoutExtension($ZipPath) + "_" + $stamp
  $changedLog   = Join-Path $outDir ("changed_simple_{0}.txt" -f $prefix)
  $skippedLog   = Join-Path $outDir ("skipped_simple_{0}.txt" -f $prefix)

  if ($changed.Count -gt 0) { Save-Utf8NoBom $changedLog ($changed -join "`r`n") }
  if ($skipped.Count -gt 0) { Save-Utf8NoBom $skippedLog ($skipped -join "`r`n") }

  # PS5.1: 'if' bir ifade değildir, önce değerleri değişkene koy
  $changedLogOut = $null
  if ($changed.Count -gt 0) { $changedLogOut = $changedLog }

  $skippedLogOut = $null
  if ($skipped.Count -gt 0) { $skippedLogOut = $skippedLog }

  [pscustomobject]@{
    appliedCount = $appliedCount
    skippedCount = $skippedCount
    backupRoot   = $backupRoot
    changedLog   = $changedLogOut
    skippedLog   = $skippedLogOut
  }
}