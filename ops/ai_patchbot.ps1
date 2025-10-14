param(
  [string]$TaskId,
  [string]$OutDir,
  [string]$RequestsDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)
# defaults
if ([string]::IsNullOrWhiteSpace($TaskId))     { $TaskId     = "UH001" }
if ([string]::IsNullOrWhiteSpace($OutDir))     { $OutDir     = "_ai_out" }
if ([string]::IsNullOrWhiteSpace($RequestsDir)){ $RequestsDir= "." }
# find latest ai_request_*.json (prefer ai_exchange/<TaskId>)
$root   = (Get-Location).Path
$prefer = Join-Path $root ("ai_exchange\"+$TaskId)
$searchBase = if (Test-Path $prefer) { $prefer } else { (Resolve-Path $RequestsDir).Path }
$req = Get-ChildItem $searchBase -Recurse -Filter "ai_request_*.json" -File -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $req) {
  Write-Host "[patchbot] no ai_request found under $searchBase"
  exit 0
}
# working dir
$work = Join-Path $env:TEMP ("ai_patch_make_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $work | Out-Null
# minimal fix: visible H1 in Django admin via override
$tplDir = Join-Path $work "templates\admin"
New-Item -ItemType Directory -Force -Path $tplDir | Out-Null
$tpl = "{% extends `"admin/base.html`" %}`n{% load i18n %}`n{% block content_title %}`n  <h1>{{ site_title|default:_(`"Site administration`") }}</h1>`n{% endblock %}`n"
[IO.File]::WriteAllText((Join-Path $tplDir "base_site.html"), $tpl, $UTF8)
# manifest.json
$manifestObj = @{
  version = 1
  task_id = $TaskId
  items   = @(@{ path="templates/admin/base_site.html"; action="modify" })
}
$manifest = $manifestObj | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $work "manifest.json"), $manifest, $UTF8)
# create zip to $OutDir
$outDirFull = Join-Path $root $OutDir
if (!(Test-Path $outDirFull)) { New-Item -ItemType Directory -Force -Path $outDirFull | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zip = Join-Path $outDirFull ("patch_"+$TaskId+"_"+$stamp+".zip")
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
[IO.Compression.ZipFile]::CreateFromDirectory($work, $zip)
# print only the zip path (workflow step can capture)
Write-Output $zip
