Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)

function Get-OtoRepoRoot {
  param([string]$ExpectedName="bakim_kalibrasyon")
  $candidates=@()
  if($env:OTOKOD_REPO){ $candidates += $env:OTOKOD_REPO }
  try{ $candidates += (git rev-parse --show-toplevel).Trim() }catch{}
  $candidates += "C:\dev\bakim_kalibrasyon"
  foreach($p in $candidates | Where-Object { $_ -and (Test-Path $_) }){
    if($p -match 'Program Files|\\Windows\\|\\AppData\\'){ continue }
    if(!(Test-Path (Join-Path $p ".git"))){ continue }
    return (Resolve-Path $p).Path
  }
  throw "Uygun repo kökü bulunamadı. OTOKOD_REPO env değişkenini ayarlayın."
}

function Use-OtoRepoRoot {
  $root = Get-OtoRepoRoot
  Set-Location -LiteralPath $root
  $global:OtoRepoRoot = (Get-Location).Path
  Write-Host "[repo] $global:OtoRepoRoot"
  return $global:OtoRepoRoot
}