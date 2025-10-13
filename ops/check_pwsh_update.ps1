param([switch]$VerboseInfo)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
function Info($m){ Write-Host $m }
function Try-Get($s){ try { & $s } catch { $null } }

$winPS = $PSVersionTable.PSVersion
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue

Info "=== PowerShell Detection ==="
Info ("Windows PowerShell: v{0}" -f $winPS)
if($pwshCmd){
  $pwshVer  = Try-Get { pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' }
  $pwshPath = $pwshCmd.Source
  if($pwshVer){ Info ("PowerShell 7+: v{0}" -f $pwshVer); if($VerboseInfo){ Info ("pwsh path : {0}" -f $pwshPath) } }
  else { Info "PowerShell 7+: found 'pwsh' but version query failed."; if($VerboseInfo){ Info ("pwsh path : {0}" -f $pwshPath) } }
} else { Info "PowerShell 7+: NOT found on PATH (command 'pwsh' missing)." }

function Get-LatestTags {
  param([string]$ApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases")
  try {
    $headers = @{ 'User-Agent' = 'ps-check' }
    $rel = Invoke-RestMethod -UseBasicParsing -Uri $ApiUrl -Headers $headers -TimeoutSec 15
    if(-not $rel){ return $null }
    $stable = $null; $lts = $null
    foreach($r in $rel){
      $tag = [string]$r.tag_name
      if($tag -match '^v(\d+)\.(\d+)\.(\d+)$'){
        if(-not $stable){ $stable = $tag }
        if($tag -match '^v7\.4\.\d+$' -and -not $lts){ $lts = $tag }
      }
      if($stable -and $lts){ break }
    }
    [pscustomobject]@{ Stable=$stable; LTS=$lts }
  } catch { if($VerboseInfo){ Info ("GitHub API error: " + $_.Exception.Message) }; $null }
}
function Parse-Ver([string]$v){ if([string]::IsNullOrWhiteSpace($v)){ return $null }; $v=$v.Trim().TrimStart('v','V'); try{ [Version]$v }catch{ $null } }

$tags = Get-LatestTags
Info "`n=== Online Versions (from GitHub) ==="
if($tags){ Info ("Stable latest : {0}" -f $tags.Stable); Info ("LTS latest    : {0}" -f $tags.LTS) } else { Info "Could not query GitHub." }

$localPwshVer = Parse-Ver (Try-Get { pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' })
$remoteStable = Parse-Ver ($tags.Stable); $remoteLts = Parse-Ver ($tags.LTS)

Info "`n=== Recommendation ==="
if(-not $pwshCmd){ Info "pwsh is not installed. You can install: Stable or LTS." }
else {
  if($localPwshVer){
    $msg = "Local pwsh : v{0}" -f $localPwshVer
    if($remoteStable){ $msg += (" | Stable latest: v{0}" -f $remoteStable) }
    if($remoteLts){   $msg += (" | LTS latest: v{0}"    -f $remoteLts) }
    Info $msg
    if($remoteStable -and $localPwshVer -lt $remoteStable){ Info "Update available: Stable is newer." }
    elseif($remoteLts -and $localPwshVer -lt $remoteLts){  Info "Update available: LTS is newer." }
    else { Info "Your pwsh looks up-to-date." }
  } else { Info "pwsh present but version could not be parsed." }
}

Info "`n=== How to update (optional) ==="
$winget = Get-Command winget -ErrorAction SilentlyContinue
$choco  = Get-Command choco  -ErrorAction SilentlyContinue
$scoop  = Get-Command scoop  -ErrorAction SilentlyContinue
if($winget){ Info "winget examples:"; Info "  winget search Microsoft.PowerShell"; Info "  winget upgrade --id Microsoft.PowerShell -s winget" }
if($choco){  Info "choco example:";   Info "  choco upgrade powershell-core -y" }
if($scoop){  Info "scoop examples:";  Info "  scoop bucket add main"; Info "  scoop update powershell" }
$global:LASTEXITCODE = 0; return