# apply_last_patch.ps1 — PS 5.1 uyumlu, terminali kapatmaz, exit yok
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# lib'i yükle
. "$PSScriptRoot\lib_patch.ps1"

# En son gelen patch_*.zip'i bul
$zip = Get-ChildItem -Path (Join-Path $PSScriptRoot '..\_otokodlama\inbox') -Filter 'patch_*.zip' -File -EA SilentlyContinue |
       Sort-Object LastWriteTime -Descending |
       Select-Object -First 1 -Expand FullName

if (-not $zip) {
  Write-Warning "Inbox'ta patch_*.zip bulunamadı."
  return
}

# Uygula
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$s = Apply-PatchZip -ZipPath $zip -RepoRoot $repoRoot

# Özet
Write-Host ("PATCH APPLIED")
Write-Host ("  zip      : {0}" -f $s.zip)
Write-Host ("  applied  : {0}" -f $s.appliedCount)
Write-Host ("  skipped  : {0}" -f $s.skippedCount)
Write-Host ("  backup   : {0}" -f $s.backupRoot)
if ($s.changedLog) { Write-Host ("  changed  : {0}" -f $s.changedLog) }
if ($s.skippedLog) { Write-Host ("  skippedL : {0}" -f $s.skippedLog) }