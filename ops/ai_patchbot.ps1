param(
  [string]$TaskId,
  [string]$OutDir,
  [string]$RequestsDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)
if ([string]::IsNullOrWhiteSpace($TaskId))     { $TaskId     = "UH001" }
if ([string]::IsNullOrWhiteSpace($OutDir))     { $OutDir     = "_ai_out" }
if ([string]::IsNullOrWhiteSpace($RequestsDir)){ $RequestsDir= "." }
$root   = (Get-Location).Path
$prefer = Join-Path $root ("ai_exchange\"+$TaskId)
$searchBase = if (Test-Path $prefer) { $prefer } else { (Resolve-Path $RequestsDir).Path }
$req = Get-ChildItem $searchBase -Recurse -Filter "ai_request_*.json" -File -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
# Çalışma alanı
$work = Join-Path $env:TEMP ("ai_patch_make_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $work | Out-Null
# Minimal çözüm: Django admin H1 override
$tplDir = Join-Path $work "templates\admin"
New-Item -ItemType Directory -Force -Path $tplDir | Out-Null
$tpl = "{% extends `"admin/base.html`" %}`n{% load i18n %}`n{% block content_title %}`n  <h1>{{ site_title|default:_(`"Site administration`") }}</h1>`n{% endblock %}`n"
[IO.File]::WriteAllText((Join-Path $tplDir "base_site.html"), $tpl, $UTF8)
# manifest.json (request olsa da olmasa da yaz)
$manifestObj = @{
  version = 1
  task_id = $TaskId
  items   = @(@{ path="templates/admin/base_site.html"; action="modify" })
}
$manifest = $manifestObj | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $work "manifest.json"), $manifest, $UTF8)
# Zip oluştur
$outDirFull = Join-Path $root $OutDir
if (!(Test-Path $outDirFull)) { New-Item -ItemType Directory -Force -Path $outDirFull | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zip = Join-Path $outDirFull ("patch_"+$TaskId+"_"+$stamp+".zip")
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
[IO.Compression.ZipFile]::CreateFromDirectory($work, $zip)
Write-Output $zip