$ErrorActionPreference = "Stop"

function Get-RepoSlug {
  $u = (& git remote get-url origin 2>$null)
  if (-not $u) { throw "origin remote yok" }
  if ($u -match 'github\.com[:/](.+?)(?:\.git)?$') { return $Matches[1] }
  throw "repo slug çözülemedi: $u"
}

function Ensure-GhAuth {
  try { & gh auth status 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { return $true } } catch {}
  Write-Host "[gh] login gerekiyor → tarayıcı açılıyor..." -ForegroundColor Yellow
  & gh auth login --hostname github.com --web --scopes "repo" | Out-Null
  & gh auth status | Out-Host
  return $true
}

function Get-OpenPrNumber {
  $n = & gh pr list --state open --limit 1 --json number --jq '.[0].number' 2>$null
  if ([string]::IsNullOrWhiteSpace($n)) { return $null }
  return [int]$n
}

function Ensure-Label {
  param([Parameter(Mandatory)][string]$Name,[string]$Color="5319e7",[string]$Description="UI pipeline checks")
  & gh label create $Name --color $Color --description $Description --force 2>$null | Out-Null
}

function Add-LabelsToPr {
  param([int]$PrNumber,[string[]]$Labels)
  if (-not $PrNumber) { throw "PR numarası yok." }
  if ($Labels -and $Labels.Length -gt 0) {
    & gh pr edit $PrNumber --add-label ($Labels -join ',') | Out-Null
  }
}

function Enable-AutoMerge {
  param([int]$PrNumber,[ValidateSet("squash","merge","rebase")]$Method="squash")
  if (-not $PrNumber) { throw "PR numarası yok." }
  & gh pr merge $PrNumber $("--$Method") --auto | Out-Host
}
