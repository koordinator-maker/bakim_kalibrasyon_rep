param(
  [Parameter(Mandatory=$true)]
  [string]$Card,
  [switch]$NoConfirm
)
$ErrorActionPreference="Stop"

if (!(Test-Path $Card)) { throw "Runcard not found: $Card" }
$lines = Get-Content $Card

foreach ($raw in $lines) {
  $line = $raw.Trim()
  if ($line -eq '' -or $line.StartsWith('#')) { continue }

  if ($line -match '^\s*ps>\s*(.+)$') {
    $cmd = $Matches[1]
    Write-Host ">> $cmd"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
      throw "Command failed (exit $LASTEXITCODE): $cmd"
    }
  } else {
    Write-Host "[SKIP] $line"
  }
}
Write-Host "[RUNCARD] done."
