param([ValidateSet('stable','lts')][string]$Channel='stable',[switch]$WhatIf)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host $m }
$winget = Get-Command winget -ErrorAction SilentlyContinue
$choco  = Get-Command choco  -ErrorAction SilentlyContinue
$scoop  = Get-Command scoop  -ErrorAction SilentlyContinue
$pkgWinget = 'Microsoft.PowerShell'
$pkgChoco  = 'powershell-core'
$pkgScoop  = 'powershell'

Say "=== PowerShell 7 install/upgrade helper ==="
if($winget){
  Say "Using winget..."
  $cmd = 'winget install --id {0} -s winget --accept-package-agreements --accept-source-agreements' -f $pkgWinget
  if($WhatIf){ Say $cmd } else { iex $cmd }
} elseif($choco){
  Say "Using choco..."
  $cmd = 'choco upgrade {0} -y' -f $pkgChoco
  if($WhatIf){ Say $cmd } else { iex $cmd }
} elseif($scoop){
  Say "Using scoop..."
  $cmd = 'scoop update {0}' -f $pkgScoop
  if($WhatIf){ Say $cmd } else { iex $cmd }
} else {
  Say "No package manager (winget/choco/scoop) found. Use MSI installer."
}

$pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
if(Test-Path $pwshPath){
  Say ("Found: " + $pwshPath)
  $env:Path = ($env:Path + ';' + [IO.Path]::GetDirectoryName($pwshPath)) -replace ';;',';'
  try { $ver = & $pwshPath -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'; Say ("pwsh version now: v" + $ver) } catch { Say "pwsh invoked but version query failed: $($_.Exception.Message)" }
} else {
  Say "pwsh.exe not found in default location yet. Open a new terminal and try 'pwsh'."
}
$global:LASTEXITCODE = 0; return