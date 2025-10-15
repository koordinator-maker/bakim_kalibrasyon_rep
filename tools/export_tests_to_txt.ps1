# === export_tests_to_txt.ps1 - Test dosyalarını tek TXT'ye topla ===
param(
  [string]$RepoRoot=".",
  [string]$OutDir="_deliverables",

  # sadece test baglantili dizin ve desenler
  [string[]]$IncludeDirs=@("tests"),
  [string[]]$IncludeFiles=@(
    "tests\*.spec.*","tests\*.test.*","tests\helpers*.js",
    "playwright.config.*","playwright.*.config.*",
    "package.json","package-lock.json"
  ),

  # haric tutulacak klasor adlari (kapsayici)
  [string[]]$ExcludeDirNames=@("node_modules","playwright-report","test-results",".git","_otokodlama","venv",".cache"),

  # opsiyonel: manifest csv de yaz
  [switch]$AlsoManifest
)

$ErrorActionPreference='Stop'

function Resolve-Repo([string]$rr){
  if($rr -and (Test-Path $rr)){ return (Resolve-Path $rr).Path }
  try{ $r = (& git rev-parse --show-toplevel) }catch{ $r = $null }
  if(-not $r){ $r = (Resolve-Path ".").Path }
  return (Resolve-Path $r).Path
}

function New-Dir([string]$p){
  $full = [IO.Path]::GetFullPath($p)
  if(-not (Test-Path $full)){ New-Item -ItemType Directory -Force -Path $full | Out-Null }
  return $full
}

# toplama
$repo = Resolve-Repo $RepoRoot
Set-Location $repo
$outDirAbs = New-Dir (Join-Path $repo $OutDir)
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$dump = Join-Path $outDirAbs ("tests_code_dump_{0}.txt" -f $ts)
$manifest = Join-Path $outDirAbs ("tests_code_dump_{0}_manifest.csv" -f $ts)

$files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'

# dizin tabanli
foreach($d in $IncludeDirs){
  $p = Join-Path $repo $d
  if(Test-Path $p){
    $g = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue
    if($g){ [void]$files.AddRange($g) }
  }
}

# desen tabanli
foreach($pat in $IncludeFiles){
  $g = Get-ChildItem -Path (Join-Path $repo '*') -Recurse -File -Include $pat -ErrorAction SilentlyContinue
  if($g){ [void]$files.AddRange($g) }
}

# haric tut
$files = $files | Where-Object {
  $full = $_.FullName
  foreach($ex in $ExcludeDirNames){
    if($full -imatch [regex]::Escape($ex)){ return $false }
  }
  return $true
}

$uniq = $files | Sort-Object FullName -Unique | Sort-Object FullName
if(-not $uniq -or $uniq.Count -eq 0){
  Write-Host "[warn] test ile ilgili dosya bulunamadi." -ForegroundColor Yellow
  exit 0
}

# TXT olusturma (UTF-8 BOM'suz)
$enc = [Text.UTF8Encoding]::new($false)
$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder

[void]$sb.Append("TEST CODE DUMP - " + (Get-Date) + $nl)
[void]$sb.Append("Repo : " + $repo + $nl)
[void]$sb.Append("File count : " + $uniq.Count + $nl)
[void]$sb.Append(("-" * 80) + $nl)

foreach($f in $uniq){
  $rel = $f.FullName.Substring($repo.Length).TrimStart('\','/')
  [void]$sb.Append($nl + "=== " + $rel + " ===" + $nl)
  try{
    $raw = Get-Content $f.FullName -Raw -Encoding UTF8
  }catch{
    $raw = Get-Content $f.FullName -Raw
  }
  # satir sonlarini CRLF yap
  $raw = $raw -replace "`r`n","`n" -replace "`r","`n"
  $raw = $raw -replace "`n",$nl
  [void]$sb.Append($raw + $nl)
}

[IO.File]::WriteAllText($dump, $sb.ToString(), $enc)
Write-Host "[ok] TXT ready: $dump" -ForegroundColor Green

if($AlsoManifest){
  "FullName,Length,LastWriteTime" | Out-File -FilePath $manifest -Encoding UTF8 -Force
  foreach($f in $uniq){
    ('"{0}",{1},{2:yyyy-MM-dd HH:mm:ss}' -f $f.FullName.Replace('"','""'), $f.Length, $f.LastWriteTime) |
      Out-File -FilePath $manifest -Append -Encoding UTF8
  }
  Write-Host "[ok] Manifest: $manifest" -ForegroundColor Green
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Dosya sayisi: $($uniq.Count)" -ForegroundColor White
Write-Host "TXT boyutu  : $((Get-Item $dump).Length / 1KB | ForEach-Object {$_.ToString('F2')}) KB" -ForegroundColor White
