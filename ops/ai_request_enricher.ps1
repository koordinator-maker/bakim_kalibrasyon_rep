param(
  [string]$TaskId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)
if ([string]::IsNullOrWhiteSpace($TaskId)) { $TaskId = "UH001" }
$root = (Get-Location).Path
$outBase = Join-Path $root "ai_exchange\$TaskId"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $outBase $stamp
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
# logs/screens to bundle (varsa)
$logs = @(); if (Test-Path "_otokodlama\out")     { $logs     = (Get-ChildItem "_otokodlama\out" -File | Sort LastWriteTime -Descending | Select -First 5 | % { $_.FullName }) }
$scrs = @(); if (Test-Path "_otokodlama\screens") { $scrs     = (Get-ChildItem "_otokodlama\screens" -File | Sort LastWriteTime -Descending | Select -First 8 | % { $_.FullName }) }
$bundle = Join-Path $outDir ("bundle_"+$TaskId+"_"+$stamp+".zip")
if ($logs.Count -gt 0 -or $scrs.Count -gt 0) {
  if (Test-Path $bundle){ Remove-Item $bundle -Force }
  Compress-Archive -Path @($logs+$scrs) -DestinationPath $bundle -Force
} else { $bundle = $null }
# repo map (kısa)
$map = New-Object System.Collections.Generic.List[string]
foreach($rootdir in @("templates","app","apps","static","src")){
  if(Test-Path $rootdir){
    $map.Add("# ["+$rootdir+"]")
    Get-ChildItem $rootdir -Recurse -File -ErrorAction SilentlyContinue |
      Select-Object -First 200 |
      ForEach-Object {
        $rel = $_.FullName -replace [regex]::Escape($root+"\\"),""
        $map.Add($rel)
      }
  }
}
[IO.File]::WriteAllLines((Join-Path $outDir "repo_map.txt"), $map, $UTF8)
# request json
$req = @{
  version = 1
  task_id = $TaskId
  intent  = "Fix visible H1 on admin pages without breaking other flows"
  constraints = @{
    allow     = @("templates/**","app/**","apps/**","static/**","src/**")
    deny      = @("ops/**",".github/**","tools/**","_otokodlama/**","venv/**")
    max_files = 5
    max_bytes = 200000
  }
  context = @{
    base_commit = "$(git rev-parse HEAD)"
    repo_map    = "repo_map.txt"
  }
  evidence = @{
    logs        = @($logs | ForEach-Object { $_ -replace [regex]::Escape($root+"\\"),"" })
    screenshots = @($scrs | ForEach-Object { $_ -replace [regex]::Escape($root+"\\"),"" })
    bundle_zip  = $(if($bundle){ Split-Path -Leaf $bundle } else { $null })
  }
}
$reqPath = Join-Path $outDir ("ai_request_"+$TaskId+"_"+$stamp+".json")
[IO.File]::WriteAllText($reqPath, ($req | ConvertTo-Json -Depth 10), $UTF8)
Write-Host "[enricher] request:" ($reqPath -replace [regex]::Escape($root+"\\"),"")