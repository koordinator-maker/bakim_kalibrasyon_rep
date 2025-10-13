# ops/loop_once.ps1 (PS 5.1 minimal & clean)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
trap { Write-Error $_; try { Stop-Transcript | Out-Null } catch {} ; return }

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

# Defaults (dÃ„Â±Ã…Å¸arÃ„Â±dan set edilmediyse)
if (-not (Get-Variable -Name CsvPath       -EA 0)) { $CsvPath = "todolist.csv" }
if (-not (Get-Variable -Name Repo          -EA 0)) { $Repo    = "." }
if (-not (Get-Variable -Name BaseUrl       -EA 0)) { $BaseUrl = "http://127.0.0.1:8010" }
if (-not (Get-Variable -Name TaskId        -EA 0)) { $TaskId  = "" }
if (-not (Get-Variable -Name RunPlan       -EA 0)) { $RunPlan = "subset" }
if (-not (Get-Variable -Name FullAfterPass -EA 0)) { $FullAfterPass = $true }

function Write-Utf8([string]$Path,[string]$Content){
  if ([string]::IsNullOrWhiteSpace($Path)) { throw "Write-Utf8: empty path" }
  $full = if([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path -Path ((Get-Location).Path) -ChildPath $Path }
  try { $full = [IO.Path]::GetFullPath($full) } catch { throw ("Write-Utf8 GetFullPath error: " + $full + " - " + $_.Exception.Message) }
  $dir = [IO.Path]::GetDirectoryName($full); if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($full,$Content,$Utf8NoBom)
}

function Read-CsvStrict([string]$Path){
  if(!(Test-Path $Path)){ throw ("CSV not found: " + $Path) }
  $rows = @(Import-Csv -LiteralPath $Path)
  if($rows.Length -eq 0){ throw ("CSV has no rows: " + $Path) }
  return $rows
}
function Select-NextTask($rows,[string]$Id){
  if($Id -and $Id.Trim().Length -gt 0){ return ($rows | Where-Object { $_.id -eq $Id } | Select-Object -First 1) }
  return ($rows | Where-Object { $_.status -match '^(?i)(todo|pending)$' } | Select-Object -First 1)
}
function Test-Server([string]$Url){
  try{
    $probe = Invoke-WebRequest -UseBasicParsing -Uri (([Uri]$Url).AbsoluteUri.TrimEnd('/') + '/admin/') -TimeoutSec 5
    return ($probe.StatusCode -ge 200 -and $probe.StatusCode -lt 500)
  } catch { return $false }
}

# Workspace
$root = (Get-Location).Path
New-Item -ItemType Directory -Force -Path "_otokodlama\out","_otokodlama\inbox","_otokodlama\logs","_otokodlama\reports","_otokodlama\tmp" | Out-Null
$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
$logPath = "_otokodlama\logs\loop_" + $ts + ".log"
try { Start-Transcript -Path $logPath -Force | Out-Null } catch {}

# 1) CSV & GÃƒÂ¶rev
$rows = Read-CsvStrict $CsvPath
$task = Select-NextTask $rows $TaskId
if(!$task){ Write-Host "Secilecek gorev bulunamadi (TODO/PENDING)."; try { Stop-Transcript | Out-Null } catch {} ; return }
Write-Host ("Secilen Gorev: " + $task.id + " - " + $task.title)

# 2) AI paket (istek)
$aiReq = @{ task = $task; base_url = $BaseUrl; note = "Read-only paket; yaniti _otokodlama/inbox altina birak." }
$reqPath = "_otokodlama\out\ai_request_" + $task.id + "_" + $ts + ".json"
Write-Utf8 $reqPath (($aiReq | ConvertTo-Json -Depth 6))

# 3) Inbox patch uygula (varsa)
$changed = @()
$inbox = "_otokodlama\inbox"
if(Test-Path $inbox){
  $cand = Get-ChildItem -Path $inbox -File | Where-Object { $_.Name -like ("*" + $task.id + "*") } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($cand){
    $stg = Join-Path "_otokodlama\tmp" ("staging_" + [IO.Path]::GetFileNameWithoutExtension($cand.Name))
    New-Item -ItemType Directory -Force -Path $stg | Out-Null
    if($cand.Extension -like ".zip"){ Expand-Archive -LiteralPath $cand.FullName -DestinationPath $stg -Force } else { Copy-Item $cand.FullName $stg -Force }
    $files = Get-ChildItem -Path $stg -Recurse -File
    foreach($f in $files){
      $rel = $f.FullName.Substring($stg.Length).TrimStart('\','/')
      $dest = Join-Path $root $rel
      $ddir = [IO.Path]::GetDirectoryName($dest); if($ddir){ New-Item -ItemType Directory -Force -Path $ddir | Out-Null }
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
      $changed += $dest
    }
  }
}

# 4) Sunucu
$serverOk = Test-Server $BaseUrl

# 5) Test: safe subset -> PASS then full; else full fallback
$summary = @{ invoked=$true; exitCode=$null; reportJson=$null; note=$null }
if (-not (Get-Variable -Name files -EA 0)) { $files = @() }
if (-not (Get-Variable -Name grep  -EA 0)) { $grep  = $null }

# --- SUBSET SEÇİMİ (dosya öncelikli, sonra doğrulanmış grep) ---
$testsRoot = Join-Path $root 'tests'
$files = @()
function Add-IfExists([string]$glob){
  if([string]::IsNullOrWhiteSpace($glob)){ return }
  $hit = Get-ChildItem -Path $testsRoot -Recurse -File -Include $glob -EA SilentlyContinue
  if($hit){ $files += $hit.FullName }
}

# ID -> dosya eşleştirme
if ($task.id -match '^(UH)\d{3}$'){
  Add-IfExists 'univ-headings*.spec.*'
  Add-IfExists 'univ-*.spec.*'
} elseif ($task.id -match '^(UF)\d{3}$'){
  Add-IfExists 'univ-forms*.spec.*'
  Add-IfExists 'univ-*.spec.*'
} elseif ($task.id -match '^E\d{3}$'){
  $lower = $task.id.ToLower()
  Add-IfExists ($lower + '*.spec.*')          # e103_*.spec.*
  Add-IfExists ('*' + $lower + '*.spec.*')    # *e103*.spec.*
  Add-IfExists ('e*.spec.*')                  # geniş emniyet ağı
}

# Dosya yoksa: grep üret ve test dosyalarında gerçekten geçtiğini doğrula
$grep = $null
if (-not $files -or $files.Count -eq 0){
  if ($task.id -like 'UH*'){ $grep = 'UNIV-HEADINGS' }
  elseif ($task.id -like 'UF*'){ $grep = 'UNIV-FORMS' }
  elseif ($task.id){ $grep = $task.id }
  elseif ($task.title){
    $first = ($task.title -split '\s+')[0]
    $grep = ($first -replace '[:\-]+$','')    # sondaki ':' veya '-' at
  }
  if ($grep){
    $match = Select-String -Path (Join-Path $testsRoot '*') -Pattern $grep -SimpleMatch -EA SilentlyContinue
    if(-not $match){ $grep = $null }          # eşleşme yoksa grep’i iptal et
  }
}

$args = @('playwright','test','--config=playwright.all.config.cjs','--headed')
if ($RunPlan -in @('auto','subset')){
  if ($files -and $files.Count -gt 0){
    $args += $files
    $summary.note = 'subset(files:' + $files.Count + ')'
  } elseif ($grep){
    $args += @('-g', $grep)
    $summary.note = 'subset(grep:' + $grep + ')'
  } else {
    $summary.note = 'full(fallback:no-subset)'
  }
} else {
  $summary.note = 'full'
}

& npx @args
$summary.exitCode = $LASTEXITCODE

# report.json yakala (Windows yolu)
$r = Get-ChildItem -Recurse -File -Filter 'report.json' |
     Where-Object { $_.FullName -like '*\playwright-report*\data\report.json' } |
     Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($r){ $summary.reportJson = $r.FullName }

# PASS subset -> full
if ($summary.exitCode -eq 0 -and $summary.note -like 'subset*' -and $FullAfterPass){
  & npx playwright test --config=playwright.all.config.cjs --headed
  $summary.exitCode = $LASTEXITCODE
  $summary.note = $summary.note + ' then full'
  $r2 = Get-ChildItem -Recurse -File -Filter 'report.json' |
        Where-Object { $_.FullName -like '*\playwright-report*\data\report.json' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($r2){ $summary.reportJson = $r2.FullName }
}

# FAIL subset -> full fallback
if ($summary.exitCode -ne 0 -and $summary.note -like 'subset*'){
  & npx playwright test --config=playwright.all.config.cjs --headed
  $summary.exitCode = $LASTEXITCODE
  $summary.note = $summary.note + ' -> full(fallback)'
  $r3 = Get-ChildItem -Recurse -File -Filter 'report.json' |
        Where-Object { $_.FullName -like '*\playwright-report*\data\report.json' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($r3){ $summary.reportJson = $r3.FullName }
}
# 6) Artefakt paketle
# 6) Artefakt paketle
# 6) Artefakt paketle
$bundle = "_otokodlama\out\bundle_" + $task.id + "_" + $ts + ".zip"
$items = @($reqPath,$logPath); if($summary.reportJson){ $items += $summary.reportJson }
if(Test-Path $bundle){ Remove-Item $bundle -Force }
$st = Join-Path "_otokodlama\tmp" ("zip_" + $task.id + "_" + $ts)
if(Test-Path $st){ Remove-Item $st -Recurse -Force -EA 0 }
New-Item -ItemType Directory -Force -Path $st | Out-Null
foreach($i in $items){ if(Test-Path $i){ Copy-Item $i (Join-Path $st ([IO.Path]::GetFileName($i))) -Force } }
Compress-Archive -Path (Join-Path $st '*') -DestinationPath $bundle -Force

# 7) CSV gÃƒÂ¼ncelle
$all = @(Import-Csv -LiteralPath $CsvPath)
foreach($row in $all){
  if($row.id -eq $task.id){
    if($summary.exitCode -eq 0){ $row.status = "done" } else { $row.status = "needs-work" }
  }
}
$bak = $CsvPath + ".bak_" + (Get-Date -Format yyyyMMddHHmmss)
Copy-Item -LiteralPath $CsvPath -Destination $bak -Force
$all | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8

# 8) Ãƒâ€“zet
"=== LOOP ONCE SUMMARY ==="
"Task: " + $task.id + " - " + $task.title
"Server OK: " + $serverOk
"Tests: invoked=" + $summary.invoked + " exitCode=" + $summary.exitCode + " note=" + $summary.note
"Changed files: " + ((@($changed)).Length)
"Out: " + (Resolve-Path $reqPath)
"Bundle: " + (Resolve-Path $bundle)

try { Stop-Transcript | Out-Null } catch {}