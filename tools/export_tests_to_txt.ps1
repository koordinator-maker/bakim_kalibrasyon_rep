# === export_tests_to_txt.ps1 - Test dosyalarini tek TXT'ye topla ===
param(
  [string]$RepoRoot=".",
  [string]$OutDir="_deliverables",
  [string[]]$IncludeDirs=@("tests"),
  [string[]]$IncludeFiles=@(
    "tests\*.spec.*","tests\*.test.*","tests\helpers*.js",
    "playwright.config.*","playwright.*.config.*",
    "package.json","package-lock.json"
  ),
  [string[]]$ExcludeDirNames=@("node_modules","playwright-report","test-results",".git","_otokodlama","venv",".cache"),
  [switch]$AlsoManifest
)

$ErrorActionPreference='Stop'

function Resolve-Repo([string]$rr){
  if($rr -and (Test-Path $rr)){ return (Resolve-Path $rr).Path }
  try{ $r = (& git rev-parse --show-toplevel 2>$null) }catch{ $r = $null }
  if(-not $r){ $r = (Resolve-Path ".").Path }
  return (Resolve-Path $r).Path
}

function New-Dir([string]$p){
  $full = [IO.Path]::GetFullPath($p)
  if(-not (Test-Path $full)){ New-Item -ItemType Directory -Force -Path $full | Out-Null }
  return $full
}

# Toplama
$repo = Resolve-Repo $RepoRoot
Set-Location $repo
$outDirAbs = New-Dir (Join-Path $repo $OutDir)
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$dump = Join-Path $outDirAbs ("tests_code_dump_{0}.txt" -f $ts)
$manifest = Join-Path $outDirAbs ("tests_code_dump_{0}_manifest.csv" -f $ts)

$files = New-Object System.Collections.ArrayList

# Dizin tabanli toplama
foreach($d in $IncludeDirs){
  $p = Join-Path $repo $d
  if(Test-Path $p){
    Write-Host "[scan] $d dizini taranıyor..." -ForegroundColor Gray
    $g = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue
    if($g){ 
      foreach($f in $g){ [void]$files.Add($f) }
      Write-Host "  [+] $($g.Count) dosya bulundu" -ForegroundColor DarkGray
    }
  }
}

# Desen tabanli toplama
Write-Host "[scan] Pattern'ler taranıyor..." -ForegroundColor Gray
foreach($pat in $IncludeFiles){
  $g = Get-ChildItem -Path (Join-Path $repo '*') -Recurse -File -Include $pat -ErrorAction SilentlyContinue
  if($g){ 
    foreach($f in $g){ [void]$files.Add($f) }
  }
}

Write-Host "[info] Toplam dosya (filtrelenmemiş): $($files.Count)" -ForegroundColor Yellow

# Haric tut
$filtered = $files | Where-Object {
  $full = $_.FullName
  foreach($ex in $ExcludeDirNames){
    if($full -match [regex]::Escape($ex)){ return $false }
  }
  return $true
}

# Unique yap
$uniq = $filtered | Sort-Object FullName -Unique

if(-not $uniq -or $uniq.Count -eq 0){
  Write-Host "[WARN] Test ile ilgili dosya bulunamadi!" -ForegroundColor Yellow
  Write-Host "  Repo: $repo" -ForegroundColor Gray
  Write-Host "  Aranan dizinler: $($IncludeDirs -join ', ')" -ForegroundColor Gray
  exit 0
}

Write-Host "[info] Filtrelenmis dosya sayisi: $($uniq.Count)" -ForegroundColor Green

# TXT olusturma (UTF-8 BOM'suz)
Write-Host "[export] TXT dosyasi olusturuluyor..." -ForegroundColor Cyan
$enc = [Text.UTF8Encoding]::new($false)
$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder

$sep = "=" * 80
[void]$sb.Append($sep + $nl)
[void]$sb.Append("  TEST CODE DUMP - Playwright Test Suite" + $nl)
[void]$sb.Append($sep + $nl)
[void]$sb.Append("  Generated : " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + $nl)
[void]$sb.Append("  Repository: " + $repo + $nl)
[void]$sb.Append("  File Count: " + $uniq.Count + $nl)
[void]$sb.Append($sep + $nl)

$processed = 0
foreach($f in $uniq){
  $processed++
  $rel = $f.FullName.Substring($repo.Length).TrimStart('\','/')
  
  Write-Progress -Activity "Export ediliyor" -Status $rel -PercentComplete (($processed/$uniq.Count)*100)
  
  [void]$sb.Append($nl + $nl)
  [void]$sb.Append("+" + ("-" * 78) + "+" + $nl)
  [void]$sb.Append("| FILE: " + $rel.PadRight(70) + " |" + $nl)
  [void]$sb.Append("| SIZE: " + ($f.Length.ToString() + " bytes").PadRight(70) + " |" + $nl)
  [void]$sb.Append("+" + ("-" * 78) + "+" + $nl)
  
  try{
    $raw = Get-Content $f.FullName -Raw -Encoding UTF8
  }catch{
    $raw = Get-Content $f.FullName -Raw
  }
  
  # Satir sonlarini normalize et
  $raw = $raw -replace "`r`n","`n" -replace "`r","`n" -replace "`n",$nl
  [void]$sb.Append($raw + $nl)
}

Write-Progress -Activity "Export ediliyor" -Completed

[IO.File]::WriteAllText($dump, $sb.ToString(), $enc)
$dumpSize = (Get-Item $dump).Length
Write-Host "[OK] TXT hazir: $dump" -ForegroundColor Green
Write-Host "     Boyut: $([math]::Round($dumpSize/1KB, 2)) KB" -ForegroundColor White

# Manifest olustur
if($AlsoManifest){
  Write-Host "[export] Manifest olusturuluyor..." -ForegroundColor Cyan
  "FullName,RelativePath,Length,LastWriteTime,Extension" | Out-File -FilePath $manifest -Encoding UTF8 -Force
  
  foreach($f in $uniq){
    $rel = $f.FullName.Substring($repo.Length).TrimStart('\','/')
    ('"{0}","{1}",{2},{3:yyyy-MM-dd HH:mm:ss},"{4}"' -f `
      $f.FullName.Replace('"','""'), `
      $rel.Replace('"','""'), `
      $f.Length, `
      $f.LastWriteTime, `
      $f.Extension) | Out-File -FilePath $manifest -Append -Encoding UTF8
  }
  
  Write-Host "[OK] Manifest: $manifest" -ForegroundColor Green
}

# Ozet
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "                    EXPORT SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  Test Dosyalari   : $($uniq.Count)" -ForegroundColor White
Write-Host "  Toplam Boyut     : $([math]::Round($dumpSize/1KB, 2)) KB" -ForegroundColor White
Write-Host "  TXT Dosyasi      : $($dump | Split-Path -Leaf)" -ForegroundColor White
if($AlsoManifest){
  Write-Host "  Manifest         : $($manifest | Split-Path -Leaf)" -ForegroundColor White
}
Write-Host ("=" * 60) -ForegroundColor Cyan