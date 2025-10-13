# ops/loop_once.ps1 - PS 5.1 clean; subset -> PASS then full; else full fallback
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
trap { Write-Error $_; try { Stop-Transcript | Out-Null } catch {} ; return }

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

# DÄ±ÅŸarÄ±dan gelmezse varsayÄ±lanlar
if (-not (Get-Variable CsvPath       -EA 0)) { $CsvPath = "todolist.csv" }
if (-not (Get-Variable Repo          -EA 0)) { $Repo    = "." }
if (-not (Get-Variable BaseUrl       -EA 0)) { $BaseUrl = "http://127.0.0.1:8010" }
if (-not (Get-Variable TaskId        -EA 0)) { $TaskId  = "" }
if (-not (Get-Variable RunPlan       -EA 0)) { $RunPlan = "subset" }  # subset | full
if (-not (Get-Variable FullAfterPass -EA 0)) { $FullAfterPass = $true }

function Write-Utf8([string]$Path,[string]$Content){
  $full = if([IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location) $Path }
  $dir = [IO.Path]::GetDirectoryName($full); if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($full,$Content,$Utf8NoBom)
}
function Read-CsvStrict([string]$Path){
  if(!(Test-Path $Path)){ throw "CSV not found: $Path" }
  $rows = @(Import-Csv -LiteralPath $Path)
  if($rows.Length -eq 0){ throw "CSV has no rows: $Path" }
  return $rows
}
function Select-NextTask($rows,[string]$Id){
  if($Id){ return ($rows | Where-Object { $_.id -eq $Id } | Select-Object -First 1) }
  return ($rows | Where-Object { $_.status -match '^(?i)(todo|pending)$' } | Select-Object -First 1)
}
function Test-Server([string]$Url){
  try{ $r = Invoke-WebRequest -UseBasicParsing -Uri (([Uri]$Url).AbsoluteUri.TrimEnd('/') + '/admin/') -TimeoutSec 5
       return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) } catch { return $false }
}

# Workspace
Set-Location $Repo
$root = (Get-Location).Path
New-Item -ItemType Directory -Force -Path "_otokodlama\out","_otokodlama\inbox","_otokodlama\logs","_otokodlama\reports","_otokodlama\tmp" | Out-Null
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = "_otokodlama\logs\loop_$ts.log"
try { Start-Transcript -Path $logPath -Force | Out-Null } catch {}

# 1) CSV & GÃ¶rev
$rows = Read-CsvStrict $CsvPath
$task = Select-NextTask $rows $TaskId
if(!$task){ Write-Host "SeÃ§ilecek gÃ¶rev bulunamadÄ± (TODO/PENDING)."; try { Stop-Transcript | Out-Null } catch {} ; return }
Write-Host ("Selected Task: " + $task.id + " - " + $task.title)

# 2) AI paket (istek)
$aiReq = @{ task = $task; base_url = $BaseUrl; note = "Read-only; dÃ¼zeltmeyi AI yapacak. YanÄ±tÄ± _otokodlama/inbox altÄ±na bÄ±rakÄ±n." }
$reqPath = "_otokodlama\out\ai_request_{0}_{1}.json" -f $task.id,$ts
Write-Utf8 $reqPath (($aiReq | ConvertTo-Json -Depth 6))

# 3) Inbox patch uygula (varsa) - sadece bizim repo dosyalarÄ±na
$changed = @()
$inbox = "_otokodlama\inbox"
if(Test-Path $inbox){
  $cand = Get-ChildItem -Path $inbox -File | Where-Object { $_.Name -like ("*" + $task.id + "*") } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($cand){
    $stg = Join-Path "_otokodlama\tmp" ("staging_" + [IO.Path]::GetFileNameWithoutExtension($cand.Name))
    New-Item -ItemType Directory -Force -Path $stg | Out-Null
    if($cand.Extension -ieq ".zip"){ Expand-Archive -LiteralPath $cand.FullName -DestinationPath $stg -Force } else { Copy-Item $cand.FullName $stg -Force }
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

# 4) Sunucu probesi (raporlamak iÃ§in)
$serverOk = Test-Server $BaseUrl

# 5) Test: SAFE SUBSET -> PASS ise FULL; FAIL ise FULL fallback
$summary = @{ invoked=$true; exitCode=$null; reportJson=$null; note=$null }
if (-not (Get-Variable files -EA 0)) { $files = @() }
if ($null -eq $files) { $files = @() } elseif ($files -isnot [System.Array]) { $files = @($files) }
if ($null -eq $grep)  { $grep  = $null }
if (-not (Get-Variable grep  -EA 0)) { $grep  = $null }

# --- SUBSET adaylarÄ±: Ã¶nce dosya, sonra doÄŸrulanmÄ±ÅŸ grep ---
$testsRoot = Join-Path $root 'tests'
function Add-IfExists([string]$glob){
  if([string]::IsNullOrWhiteSpace($glob)){ return }
  $hit = Get-ChildItem -Path $testsRoot -Recurse -File -Include $glob -EA SilentlyContinue
  if($hit){ $files += $hit.FullName }
}
# ID->dosya
if ($task.id -match '^(UH)\d{3}$'){
  Add-IfExists 'univ-headings*.spec.*'; Add-IfExists 'univ-*.spec.*'
} elseif ($task.id -match '^(UF)\d{3}$'){
  Add-IfExists 'univ-forms*.spec.*'; Add-IfExists 'univ-*.spec.*'
} elseif ($task.id -match '^E\d{3}$'){
  $lower = $task.id.ToLower()
  Add-IfExists ($lower + '*.spec.*')
  Add-IfExists ('*' + $lower + '*.spec.*')
}
# Dosya yoksa, grep Ã¼ret + doÄŸrula
if (-not $files -or $files.Count -eq 0){
  if ($task.id -like 'UH*'){ $grep = 'UNIV-HEADINGS' }
  elseif ($task.id -like 'UF*'){ $grep = 'UNIV-FORMS' }
  elseif ($task.id){ $grep = $task.id }
  elseif ($task.title){
    $first = ($task.title -split '\s+')[0]; $grep = ($first -replace '[:\-]+$','')
  }
  if($grep){
    $hit = Select-String -Path (Join-Path $testsRoot '*') -Pattern $grep -SimpleMatch -EA SilentlyContinue
    if(-not $hit){ $grep = $null }
  }
}

# --- Playwright Ã§aÄŸrÄ±larÄ±: PS 5.1 gÃ¼venli Start-Process ---
function Invoke-Npx([string]$argList){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'npx'
  $psi.Arguments = $argList
  $psi.WorkingDirectory = $root
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $p.WaitForExit()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $out | Out-File -Encoding UTF8 -FilePath (Join-Path $root '_otokodlama\out\cmd_stdout.txt')
  $err | Out-File -Encoding UTF8 -FilePath (Join-Path $root '_otokodlama\out\cmd_stderr.txt')
  return $p.ExitCode
}

# SUBSET mi FULL mÃ¼?
$argList = 'playwright test --config="playwright.all.config.cjs" --headed'
if ($RunPlan -in @('auto','subset')){
  if ($files -and $files.Count -gt 0){
    $quoted = $files | ForEach-Object { '"' + ($_ -replace '"','""') + '"' }
    $argList = $argList + ' ' + ($quoted -join ' ')
    $summary.note = "subset(files:$($files.Count))"
  } elseif ($grep) {
    $argList = $argList + ' --grep "' + ($grep -replace '"','""') + '"'
    $summary.note = "subset(grep:$grep)"
  } else {
    $summary.note = "full(fallback:no-subset)"
  }
} else {
  $summary.note = "full"
}

$summary.exitCode = Invoke-Npx $argList

# report.json bulun
$r = Get-ChildItem -Recurse -File -Filter 'report.json' |
     Where-Object { $_.FullName -like '*\playwright-report*\data\report.json' } |
     Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($r){ $summary.reportJson = $r.FullName }

# PASS subset -> FULL
if ($summary.exitCode -eq 0 -and $summary.note -like 'subset*' -and $FullAfterPass){
  $summary.exitCode = Invoke-Npx 'playwright test --config="playwright.all.config.cjs" --headed'
  $summary.note = $summary.note + ' then full'
}
# FAIL subset -> FULL fallback
if ($summary.exitCode -ne 0 -and $summary.note -like 'subset*'){
  $summary.exitCode = Invoke-Npx 'playwright test --config="playwright.all.config.cjs" --headed'
  $summary.note = $summary.note + ' -> full(fallback)'
}

# 6) Paketle
$bundle = "_otokodlama\out\bundle_{0}_{1}.zip" -f $task.id,$ts
if(Test-Path $bundle){ Remove-Item $bundle -Force }
$st = Join-Path "_otokodlama\tmp" ("zip_" + $task.id + "_" + $ts)
if(Test-Path $st){ Remove-Item $st -Recurse -Force -EA 0 }
New-Item -ItemType Directory -Force -Path $st | Out-Null
Copy-Item $reqPath (Join-Path $st ([IO.Path]::GetFileName($reqPath))) -Force
Copy-Item $logPath (Join-Path $st ([IO.Path]::GetFileName($logPath))) -Force
if($summary.reportJson){ Copy-Item $summary.reportJson (Join-Path $st 'report.json') -Force }
Compress-Archive -Path (Join-Path $st '*') -DestinationPath $bundle -Force

# 7) CSV gÃ¼ncelle (sadece status alanÄ±)
$all = @(Import-Csv -LiteralPath $CsvPath)
foreach($row in $all){
  if($row.id -eq $task.id){
    if ($summary.exitCode -eq 0) { $row.status = "done" } else { $row.status = "needs-work" }
  }
}
$bak = $CsvPath + ".bak_" + (Get-Date -Format yyyyMMddHHmmss)
Copy-Item -LiteralPath $CsvPath -Destination $bak -Force
$all | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8

# 8) Ã–zet
"=== LOOP ONCE SUMMARY ==="
"Task: " + $task.id + " - " + $task.title
"Server OK: " + $serverOk
"Tests: invoked=" + $summary.invoked + " exitCode=" + $summary.exitCode + " note=" + $summary.note
"Changed files: " + ((@($changed)).Length)
"Out: " + (Resolve-Path $reqPath)
"Bundle: " + (Resolve-Path $bundle)

try { Stop-Transcript | Out-Null } catch {}