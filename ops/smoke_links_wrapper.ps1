param(
  [string]$Base,
  [string]$Start,
  [string]$Out,
  [int]   $Depth,
  [int]   $Limit,
  [string]$PathPrefix,
  [int]   $Timeout,
  [string]$OkRedirectTo
)
& "$PSScriptRoot\smoke_links.ps1" `
  -Base $Base `
  -Start $Start `
  -Out $Out `
  -Depth $Depth `
  -Limit $Limit `
  -PathPrefix $PathPrefix `
  -Timeout $Timeout `
  -OkRedirectTo $OkRedirectTo
