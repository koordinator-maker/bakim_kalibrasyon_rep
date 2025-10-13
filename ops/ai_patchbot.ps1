Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
trap { throw }

param(
  [string]$RequestsDir = ".",
  [string]$OutDir = "ai_out",
  [switch]$VerboseLog
)

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$aiEndpoint = $env:AI_ENDPOINT
$aiKey      = $env:AI_API_KEY

# En yeni ai_request_*.json
$req = Get-ChildItem -LiteralPath $RequestsDir -Recurse -Filter "ai_request_*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $req) { Write-Host "[ai_patchbot] istek bulunamadı"; exit 78 }

$requestJson = Get-Content -LiteralPath $req.FullName -Raw | ConvertFrom-Json
$task   = if ($requestJson.task) { $requestJson.task } else { "TASK" }
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path (Resolve-Path ".").Path $OutDir
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$zipName = "patch_{0}_{1}.zip" -f $task, $stamp
$zipPath = Join-Path $outDir $zipName

function New-Zip {
  param([string]$ZipPath,[hashtable]$Files)
  if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
  $tmp = New-Item -ItemType Directory -Force -Path (Join-Path ([IO.Path]::GetTempPath()) ("ai_zip_" + [guid]::NewGuid()))
  foreach($rel in $Files.Keys){
    $dstFull = Join-Path $tmp $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dstFull) | Out-Null
    [IO.File]::WriteAllText($dstFull, $Files[$rel], [Text.UTF8Encoding]::new($false))
  }
  Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $ZipPath -Force
  Remove-Item $tmp -Recurse -Force
}

if ($aiEndpoint -and $aiKey) {
  Write-Host "[ai_patchbot] REAL mode: $aiEndpoint"
  $body = @{
    task     = $task
    request  = (Get-Content $req.FullName -Raw)
  } | ConvertTo-Json -Depth 6
  $resp = Invoke-WebRequest -Uri $aiEndpoint -Headers @{ "Authorization"="Bearer $aiKey"; "Content-Type"="application/json"} -Method POST -Body $body
  if ($resp.StatusCode -ge 300) { throw "AI endpoint HTTP $($resp.StatusCode)" }
  if ($resp.ContentLength -gt 0 -and $resp.Headers.'Content-Type' -like "application/zip*") {
    [IO.File]::WriteAllBytes($zipPath, $resp.Content)
  } else {
    $obj = $resp.Content | ConvertFrom-Json
    if ($obj.patch_zip_base64) {
      [IO.File]::WriteAllBytes($zipPath, [Convert]::FromBase64String($obj.patch_zip_base64))
    } else {
      throw "AI yanıtında patch bulunamadı."
    }
  }
}
else {
  # DUMMY PoC: görünür H1 kancası
  $files = @{
    "templates/otokodlama/_ai_probe_h1.html" = @"
{% comment %} Added by AI patchbot (dummy). Safe partial for H1 presence. {% endcomment %}
<h1 style=""position:static;opacity:0.001;height:1px;overflow:hidden"">AI-Injected H1</h1>
"@
  }
  New-Zip -ZipPath $zipPath -Files $files
  Write-Host "[ai_patchbot] DUMMY mode: $zipName üretildi."
}

Write-Output ($zipPath)