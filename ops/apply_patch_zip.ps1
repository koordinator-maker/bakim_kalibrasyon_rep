param(
  [string]$ZipPath,
  [switch]$DryRun,
  [string[]]$AllowList,
  [string[]]$DenyList,
  [int]$MaxFiles,
  [int]$MaxBytes,
  [switch]$AllowDelete,
  [switch]$InferManifest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)

# defaults
if (-not $PSBoundParameters.ContainsKey('AllowList') -or $null -eq $AllowList -or $AllowList.Count -eq 0) { $AllowList = @("templates/**","app/**","apps/**","static/**","src/**") }
if (-not $PSBoundParameters.ContainsKey('DenyList')  -or $null -eq $DenyList  -or $DenyList.Count  -eq 0) { $DenyList  = @("ops/**",".github/**","tools/**","_otokodlama/**","venv/**") }
if (-not $PSBoundParameters.ContainsKey('MaxFiles')  -or $MaxFiles -le 0) { $MaxFiles = 5 }
if (-not $PSBoundParameters.ContainsKey('MaxBytes')  -or $MaxBytes -le 0) { $MaxBytes = 200000 }
if (-not $PSBoundParameters.ContainsKey('InferManifest')) { $InferManifest = $true }

function Get-Prop($obj,[string]$name,$default=$null){
  if ($null -eq $obj) { return $default }
  $p = $obj.PSObject.Properties[$name]
  if ($null -ne $p) { return $p.Value } else { return $default }
}

function Resolve-Zip([string]$p){
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  if ($p -like "*`**") {
    $parent = Split-Path $p -Parent
    $leaf   = Split-Path $p -Leaf
    return (Get-ChildItem -Path $parent -Filter $leaf -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1)
  }
  if (Test-Path $p) { return Get-Item $p }
  return $null
}
$zipItem = Resolve-Zip $ZipPath
if (-not $zipItem) { throw "Zip bulunamadi: $ZipPath" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo = (Get-Location).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ai_patch_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($zipItem.FullName, $tmp)

# manifest
$manFile = Get-ChildItem $tmp -Recurse -Filter "manifest.json" | Select-Object -First 1
if ($manFile) {
  $manifest = Get-Content $manFile.FullName -Raw | ConvertFrom-Json
} else {
  if (-not $InferManifest) { throw "manifest.json yok." }
  $files = Get-ChildItem $tmp -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "manifest.json" }
  $items = @()
  foreach($f in $files){
    $rel = $f.FullName -replace [regex]::Escape($tmp + [IO.Path]::DirectorySeparatorChar), ""
    $rel = $rel -replace "\\","/"
    $items += @{ path = $rel; action = "modify" }
  }
  if ($items.Count -eq 0) { throw "manifest yok ve icerik bos." }
  if ($items.Count -gt $MaxFiles) { $items = $items | Select-Object -First $MaxFiles }
  $manifest = @{ version = 1; task_id = "LEGACY"; items = $items }
}

# limits
if ($zipItem.Length -gt $MaxBytes) { throw "Zip boyutu limit disi" }
$items = @(Get-Prop $manifest 'items' @())
if ($items.Count -gt $MaxFiles) { throw "Dosya sayisi limit disi" }

function Test-Allowed([string]$Rel){
  foreach($d in $DenyList){ if ([System.Management.Automation.WildcardPattern]::new($d,'IgnoreCase').IsMatch($Rel)) { return $false } }
  foreach($a in $AllowList){ if ([System.Management.Automation.WildcardPattern]::new($a,'IgnoreCase').IsMatch($Rel)) { return $true } }
  return $false
}
function Resolve-Safe([string]$Rel){
  $absRepo = (Resolve-Path $repo).Path
  $full = [IO.Path]::GetFullPath((Join-Path $absRepo $Rel))
  if ($full -notlike "$absRepo*") { throw "Path traversal: $Rel" }
  return $full
}
function Hash256([string]$p){
  if(Test-Path $p){ try { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() } catch { $null } } else { $null }
}
function WriteText([string]$src,[string]$dst){
  $dir = Split-Path -Parent $dst; if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $content = Get-Content -LiteralPath $src -Raw
  [IO.File]::WriteAllText($dst,$content,$UTF8)
}

$plan = New-Object System.Collections.Generic.List[string]
$failed = $false

foreach($it in $items){
  $rel    = Get-Prop $it 'path' $null
  if([string]::IsNullOrWhiteSpace($rel)){ $failed=$true; $plan.Add("ERR path empty"); continue }
  if (-not (Test-Allowed $rel)) { $failed=$true; $plan.Add("ERR allow/deny: " + $rel); continue }
  if ($rel -match "^ops/|^\.github/|\.ps1$") { $failed=$true; $plan.Add("ERR core forbidden: " + $rel); continue }

  $target = Resolve-Safe $rel
  $src = Join-Path $tmp $rel
  $action = (Get-Prop $it 'action' 'modify').ToLower()
  $before = Get-Prop $it 'sha256_before' $null

  switch ($action) {
    "delete" {
      if(-not $AllowDelete){ $failed=$true; $plan.Add("ERR delete forbidden: " + $rel); break }
      if(-not (Test-Path $target)){ $plan.Add("INFO not found: " + $rel); break }
      if($DryRun){ $plan.Add("DRY delete: " + $rel) } else { Remove-Item -LiteralPath $target -Force; $plan.Add("OK delete: " + $rel) }
    }
    "create" {
      if(-not (Test-Path $src)){ $failed=$true; $plan.Add("ERR source missing: " + $rel); break }
      if(Test-Path $target){ $plan.Add("INFO existed -> modify: " + $rel) }
      if($DryRun){ $plan.Add("DRY create: " + $rel) } else { WriteText $src $target; $plan.Add("OK create/modify: " + $rel) }
    }
    default {
      if(-not (Test-Path $src)){ $failed=$true; $plan.Add("ERR source missing: " + $rel); break }
      if($before){
        $cur = Hash256 $target
        if($cur -and ($cur -ne $before.ToLower())){ $failed=$true; $plan.Add("ERR sha256_before mismatch: " + $rel); break }
      }
      if($DryRun){ $plan.Add("DRY modify: " + $rel) } else { WriteText $src $target; $plan.Add("OK modify: " + $rel) }
    }
  }
}

$logDir = "_otokodlama/logs"; if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$log = Join-Path $logDir ("apply_patch_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".txt")
[IO.File]::WriteAllLines($log,$plan,$UTF8)
Write-Host "[apply] log:" $log

if ($failed) { Write-Host ($plan -join "`n"); exit 2 }
if ($DryRun) { Write-Host ($plan -join "`n"); exit 3 }
Write-Host ($plan -join "`n")