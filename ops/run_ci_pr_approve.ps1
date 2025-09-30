param()
if (-not $env:OZKAN_PAT) {
  Write-Error "Set OZKAN_PAT (ozkanrepo1 PAT, scopes: repo, read:org)"; exit 1
}
$env:GH_TOKEN = $env:OZKAN_PAT
try {
  & "$PSScriptRoot\auto_pr.ps1" -WaitForMerge
} finally {
  Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
}

