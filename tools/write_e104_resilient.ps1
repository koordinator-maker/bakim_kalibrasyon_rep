Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$repo = (& git rev-parse --show-toplevel) 2>$null; if(-not $repo){ $repo=(Get-Location).Path }
$path = Join-Path $repo 'tests\e104_create_and_delete_equipment.spec.js'
New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
$js = Get-Content -Raw -Encoding UTF8 $path
if(Test-Path $path){
  $bak = "$path.bak_$((Get-Date).ToString('yyyyMMddHHmmss'))"
  Copy-Item $path $bak -Force
  Write-Host "[bak] $bak"
}
[IO.File]::WriteAllText($path, $js, [Text.UTF8Encoding]::new($false))
Write-Host "[ok] wrote $path" -ForegroundColor Green