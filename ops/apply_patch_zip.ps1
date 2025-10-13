Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$UTF8=[Text.UTF8Encoding]::new($false)

param(
  [string]$ZipPath,
  [switch]$DryRun,
  [string[]]$AllowList  = @("templates/**","app/**","apps/**","static/**","src/**"),
  [string[]]$DenyList   = @("ops/**",".github/**","tools/**","_otokodlama/**","venv/**"),
  [int]$MaxFiles        = 5,
  [int]$MaxBytes        = 200000,
  [switch]$AllowDelete
)

# wildcard destekle
function Resolve-Zip([string]$p){
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  if ($p -like "*`**") { return (Get-ChildItem -Path (Split-Path $p -Parent) -Filter (Split-Path $p -Leaf) -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }
  if (Test-Path $p) { return Get-Item $p }
  return $null
}
$zipItem = Resolve-Zip $ZipPath
if (-not $zipItem) { throw "Zip bulunamadı: $ZipPath" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo = (Get-Location).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ai_patch_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($zipItem.FullName, $tmp)

$man = Get-ChildItem $tmp -Recurse -Filter "manifest.json" | Select-Object -First 1
if (-not $man) { throw "manifest.json yok." }
$manifest = Get-Content $man.FullName -Raw | ConvertFrom-Json

# limitler
if ($zipItem.Length -gt $MaxBytes) { throw "Zip boyutu limit dışı ($($zipItem.Length) > $MaxBytes)" }
if ($manifest.items.Count -gt $MaxFiles) { throw "Dosya sayısı limit dışı ($($manifest.items.Count) > $MaxFiles)" }

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
function Hash256([string]$p){ if(Test-Path $p){ (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() } else { $null } }
function WriteText([string]$src,[string]$dst){
  $dir = Split-Path -Parent $dst; if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $content = Get-Content -LiteralPath $src -Raw
  [IO.File]::WriteAllText($dst,$content,$UTF8)
}

$plan = New-Object System.Collections.Generic.List[string]
$failed = $false

foreach($it in $manifest.items){
  $rel = $it.path; if([string]::IsNullOrWhiteSpace($rel)){ $failed=$true; $plan.Add("✗ path boş"); continue }
  if (-not (Test-Allowed $rel)) { $failed=$true; $plan.Add("✗ allow/deny ihlali: $rel"); continue }
  if ($rel -match "^ops/|^\.github/|\.ps1$") { $failed=$true; $plan.Add("✗ çekirdek yasak: $rel"); continue }

  $target = Resolve-Safe $rel
  $src = Join-Path $tmp $rel
  $action = (""+$it.action).ToLower()
  if ($action -eq "") { $action = "modify" }

  switch ($action) {
    "delete" { if(-not $AllowDelete){ $failed=$true; $plan.Add("✗ delete yasak: $rel"); break }
               if(-not (Test-Path $target)){ $plan.Add("• yoktu: $rel"); break }
               if($DryRun){ $plan.Add("DRY delete: $rel") } else { Remove-Item -LiteralPath $target -Force; $plan.Add("✓ delete: $rel") } }
    "create" { if(-not (Test-Path $src)){ $failed=$true; $plan.Add("✗ kaynak yok: $rel"); break }
               if(Test-Path $target){ $plan.Add("• vardı → modify: $rel") }
               if($DryRun){ $plan.Add("DRY create: $rel") } else { WriteText $src $target; $plan.Add("✓ create/modify: $rel") } }
    default  { if(-not (Test-Path $src)){ $failed=$true; $plan.Add("✗ kaynak yok: $rel"); break }
               $before = (""+$it.sha256_before)
               if($before){ $cur = Hash256 $target; if($cur -and ($cur -ne $before.ToLower())){ $failed=$true; $plan.Add("✗ sha256_before uyuşmadı: $rel"); break } }
               if($DryRun){ $plan.Add("DRY modify: $rel") } else { WriteText $src $target; $plan.Add("✓ modify: $rel") } }
  }
}

$logDir = "_otokodlama/logs"; if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$log = Join-Path $logDir ("apply_patch_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".txt")
[IO.File]::WriteAllLines($log,$plan,$UTF8)
Write-Host "[apply] log:" $log

if ($failed) { Write-Host ($plan -join "`n"); exit 2 }
if ($DryRun) { Write-Host ($plan -join "`n"); exit 3 }
Write-Host ($plan -join "`n")