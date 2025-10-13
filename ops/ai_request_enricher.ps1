Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)

param(
  [string]$TaskId,
  [string]$OutDir       = "ai_exchange",
  [string[]]$Evidence   = @("_otokodlama/out","_otokodlama/screens"),
  [string[]]$AllowList  = @("templates/**","app/**","apps/**","static/**","src/**"),
  [string[]]$DenyList   = @("ops/**",".github/**","tools/**","_otokodlama/**","venv/**"),
  [int]$MaxFiles        = 5,
  [int]$MaxBytes        = 200000
)
if ([string]::IsNullOrWhiteSpace($TaskId)) { throw "TaskId gerekli." }

function New-Dir([string]$p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$base  = Join-Path (Get-Location).Path $OutDir
$taskDir = Join-Path $base $TaskId
$outTaskStamp = Join-Path $taskDir $stamp
New-Dir $outTaskStamp

# repo_map.txt (allow köklerinden ağaç)
$map = New-Object System.Collections.Generic.List[string]
foreach($pat in $AllowList){
  $root = $pat.Split('/')[0]
  if(Test-Path $root){
    $map.Add("# [$root]")
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
      Select-Object -First 200 |
      ForEach-Object { $rel = $_.FullName -replace [regex]::Escape((Get-Location).Path+"\\"),""; $map.Add($rel) }
  }
}
[IO.File]::WriteAllLines((Join-Path $outTaskStamp "repo_map.txt"), $map, $UTF8)

# evidences bundle
$evi=@(); foreach($e in $Evidence){ if(Test-Path $e){ $evi += $e } }
$bundleZip = Join-Path $outTaskStamp ("bundle_"+$TaskId+"_"+$stamp+".zip")
if($evi.Count -gt 0){ if(Test-Path $bundleZip){ Remove-Item $bundleZip -Force }; Compress-Archive -Path $evi -DestinationPath $bundleZip -Force }

# ai_request.json
$req = @{
  version = 1
  task_id = $TaskId
  intent  = "Ensure visible H1 on admin without breaking other flows."
  constraints = @{ allow=@("templates/**","app/**","apps/**","static/**","src/**"); deny=@("ops/**",".github/**","tools/**","_otokodlama/**","venv/**"); max_files=5; max_bytes=200000 }
  context = @{ base_commit = "$(git rev-parse HEAD)"; repo_map = "repo_map.txt" }
  evidence = @{
    logs        = (Get-ChildItem "_otokodlama/out" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object { $_.FullName -replace [regex]::Escape((Get-Location).Path+"\\"),"" })
    screenshots = (Get-ChildItem "_otokodlama/screens" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object { $_.FullName -replace [regex]::Escape((Get-Location).Path+"\\"),"" })
    bundle_zip  = (Test-Path $bundleZip) ? (Split-Path -Leaf $bundleZip) : $null
  }
}
$reqPath = Join-Path $outTaskStamp ("ai_request_"+$TaskId+"_"+$stamp+".json")
[IO.File]::WriteAllText($reqPath, ($req | ConvertTo-Json -Depth 10), $UTF8)
Write-Output $reqPath