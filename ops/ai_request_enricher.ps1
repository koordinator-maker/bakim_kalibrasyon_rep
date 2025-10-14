param(
  [string]$TaskId,
  [string]$OutDir,
  [string[]]$Evidence,
  [string[]]$AllowList,
  [string[]]$DenyList,
  [int]$MaxFiles,
  [int]$MaxBytes
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($TaskId)) { throw "TaskId gerekli." }
if (-not $PSBoundParameters.ContainsKey('OutDir')    -or [string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = "ai_exchange" }
if (-not $PSBoundParameters.ContainsKey('Evidence')  -or $null -eq $Evidence  -or $Evidence.Count  -eq 0) { $Evidence  = @("_otokodlama/out","_otokodlama/screens") }
if (-not $PSBoundParameters.ContainsKey('AllowList') -or $null -eq $AllowList -or $AllowList.Count -eq 0) { $AllowList = @("templates/**","app/**","apps/**","static/**","src/**") }
if (-not $PSBoundParameters.ContainsKey('DenyList')  -or $null -eq $DenyList  -or $DenyList.Count  -eq 0) { $DenyList  = @("ops/**",".github/**","tools/**","_otokodlama/**","venv/**") }
if (-not $PSBoundParameters.ContainsKey('MaxFiles')  -or $MaxFiles -le 0) { $MaxFiles = 5 }
if (-not $PSBoundParameters.ContainsKey('MaxBytes')  -or $MaxBytes -le 0) { $MaxBytes = 200000 }

function New-Dir([string]$p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$base  = Join-Path (Get-Location).Path $OutDir
$taskDir = Join-Path $base $TaskId
$outTaskStamp = Join-Path $taskDir $stamp
New-Dir $outTaskStamp

# repo_map.txt
$map = New-Object System.Collections.Generic.List[string]
foreach($pat in $AllowList){
  $root = $pat.Split('/')[0]
  if(Test-Path $root){
    $map.Add("# [" + $root + "]")
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
      Select-Object -First 200 |
      ForEach-Object {
        $rel = $_.FullName -replace [regex]::Escape((Get-Location).Path+"\\"),""
        $map.Add($rel)
      }
  }
}
[IO.File]::WriteAllLines((Join-Path $outTaskStamp "repo_map.txt"), $map, $UTF8)

# evidences bundle (opsiyonel)
$evi=@(); foreach($e in $Evidence){ if(Test-Path $e){ $evi += $e } }
$bundleZip = Join-Path $outTaskStamp ("bundle_"+$TaskId+"_"+$stamp+".zip")
if($evi.Count -gt 0){
  if(Test-Path $bundleZip){ Remove-Item $bundleZip -Force }
  Compress-Archive -Path $evi -DestinationPath $bundleZip -Force
}
$bundleLeaf = $null; if (Test-Path $bundleZip) { $bundleLeaf = Split-Path -Leaf $bundleZip }

# ai_request.json
$logs = Get-ChildItem "_otokodlama/out" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object { $_.FullName -replace [regex]::Escape((Get-Location).Path+"\\"),"" }
$screens = Get-ChildItem "_otokodlama/screens" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object { $_.FullName -replace [regex]::Escape((Get-Location).Path+"\\"),"" }

$req = @{
  version = 1
  task_id = $TaskId
  intent  = "Ensure visible H1 on admin without breaking other flows."
  constraints = @{
    allow     = $AllowList
    deny      = $DenyList
    max_files = $MaxFiles
    max_bytes = $MaxBytes
  }
  context = @{
    base_commit = "$(git rev-parse HEAD)"
    repo_map    = "repo_map.txt"
  }
  evidence = @{
    logs        = $logs
    screenshots = $screens
    bundle_zip  = $bundleLeaf
  }
}
$reqPath = Join-Path $outTaskStamp ("ai_request_"+$TaskId+"_"+$stamp+".json")
[IO.File]::WriteAllText($reqPath, ($req | ConvertTo-Json -Depth 10), $UTF8)
Write-Output $reqPath