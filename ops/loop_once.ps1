# ops/loop_once.ps1  (Windows PowerShell 5.1)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
trap { Write-Error $_; try { Stop-Transcript | Out-Null } catch {}; return }

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

# ---- Kullanıcı değişkenleri (tanımlı değilse varsayılan ata) ----
if (-not (Get-Variable -Name CsvPath           -ErrorAction SilentlyContinue)) { $CsvPath = "todolist.csv" }
if (-not (Get-Variable -Name Repo              -ErrorAction SilentlyContinue)) { $Repo    = "." }
if (-not (Get-Variable -Name BaseUrl           -ErrorAction SilentlyContinue)) { $BaseUrl = "http://127.0.0.1:8010" }
if (-not (Get-Variable -Name TaskId            -ErrorAction SilentlyContinue)) { $TaskId  = "" } # boşsa ilk TODO/PENDING seçilir
if (-not (Get-Variable -Name NoPush            -ErrorAction SilentlyContinue)) { $NoPush = $false }
if (-not (Get-Variable -Name NoServerStart     -ErrorAction SilentlyContinue)) { $NoServerStart = $false }
if (-not (Get-Variable -Name ServerWaitSeconds -ErrorAction SilentlyContinue)) { $ServerWaitSeconds = 40 }
if (-not (Get-Variable -Name NoScreenshot      -ErrorAction SilentlyContinue)) { $NoScreenshot = $false }

# ---- Helpers ----
function Resolve-Root {
  try { $r = (git rev-parse --show-toplevel) 2>$null } catch { $r = $null }
  if ($r -and (Test-Path $r)) { $r } else { (Get-Location).Path }
}

function Write-Utf8([string]$Path,[string]$Content){
  $full = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
  $dir  = [IO.Path]::GetDirectoryName($full)
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($full,$Content,$Utf8NoBom)
}

function Read-CsvStrict([string]$Path){
  if(!(Test-Path $Path)){ throw "CSV bulunamadı: $Path" }
  $raw = Get-Content -LiteralPath $Path -Raw
  if([string]::IsNullOrWhiteSpace($raw)){ throw "CSV boş: $Path" }

  # HER DURUMDA DİZİ
  $rows = @(Import-Csv -LiteralPath $Path)

  if($rows.Length -eq 0){ throw "CSV satır yok: $Path" }
  $first = $rows[0]

  $need = @('id','title','severity','area','evidence','timestamp')
  foreach($k in $need){
    if(-not ($first.PSObject.Properties.Name -contains $k)){
      throw "Eksik sütun: $k"
    }
  }
  return $rows
}

function Convert-TodoCsvToJson([string]$Csv,[string]$OutJson){
  $rows = Read-CsvStrict $Csv
  foreach($r in $rows){
    if(-not ($r.PSObject.Properties.Name -contains 'status')){ $r | Add-Member -NotePropertyName status -NotePropertyValue "todo" -Force }
    elseif([string]::IsNullOrWhiteSpace($r.status)){ $r.status = "todo" }
  }
  $json = ($rows | ConvertTo-Json -Depth 6)
  Write-Utf8 $OutJson $json
  return $rows
}

function Select-NextTask($rows,[string]$Id){
  if($Id){ ($rows | Where-Object { $_.id -eq $Id } | Select-Object -First 1) }
  else   { ($rows | Where-Object { $_.status -match '^(todo|pending)$' } | Select-Object -First 1) }
}

function Test-ServerReachable([string]$Url){
  try{
    $u = [Uri]$Url
    $probe = Invoke-WebRequest -UseBasicParsing -Uri ($u.AbsoluteUri.TrimEnd('/') + "/admin/") -TimeoutSec 5
    return ($probe.StatusCode -ge 200 -and $probe.StatusCode -lt 500)
  } catch { return $false }
}

function Ensure-Server([string]$Url,[int]$WaitSeconds){
  if(Test-ServerReachable $Url){ return $true }
  if($NoServerStart){ return $false }
  $port = ([Uri]$Url).Port
  $psi  = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "python"
  $psi.Arguments = "manage.py runserver 127.0.0.1:$port"
  $psi.WorkingDirectory = (Get-Location).Path
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.CreateNoWindow = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  while((Get-Date) -lt $deadline){
    Start-Sleep -Milliseconds 700
    if(Test-ServerReachable $Url){ return $true }
  }
  return (Test-ServerReachable $Url)
}

function Stamp-Rev([string]$Old,[ref]$NewText){
  $now = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  if([string]::IsNullOrWhiteSpace($Old)){ $NewText.Value = "Rev: $now r1`r`n"; return }
  $lines = $Old -split "(`r`n|`n)"
  if($lines.Length -gt 0 -and $lines[0] -match '^Rev:\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+r(\d+)\s*$'){
    $n = [int]$Matches[1] + 1; $lines[0] = "Rev: $now r$n"; $NewText.Value = ($lines -join "`r`n")
  } else { $NewText.Value = "Rev: $now r1`r`n" + $Old }
}

function Stamp-And-Write([string]$Path,[string]$Content){
  $existing = ""; if(Test-Path $Path){ $existing = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 }
  $txt = ""; Stamp-Rev $existing ([ref]$txt)
  if($Content){ if($Content.Length -gt 0 -and $Content[0] -eq [char]0xFEFF){ $Content = $Content.Substring(1) }; $txt = $txt + $Content }
  Write-Utf8 $Path $txt
}

function Is-TextFile([string]$Path){
  $ext = [IO.Path]::GetExtension($Path); if($null -eq $ext){ $ext = "" }; $ext = $ext.ToLowerInvariant()
  $texts = @(".ps1",".psm1",".psd1",".py",".js",".cjs",".mjs",".ts",".json",".txt",".md",".css",".html",".htm",".yml",".yaml",".ini",".cfg",".toml")
  return ($texts -contains $ext)
}

function Apply-AIChangesFromInbox([string]$TaskId,[string]$Inbox,[string]$RepoRoot,[ref]$Changed){
  $Changed.Value = @()
  if(!(Test-Path $Inbox)){ return }
  $candidates = Get-ChildItem -Path $Inbox -File | Sort-Object LastWriteTime -Descending
  if(!$candidates){ return }
  foreach($f in $candidates){
    $name = $f.Name
    if($TaskId -and ($name -notmatch [regex]::Escape($TaskId))){ continue }
    $staging = Join-Path "_otokodlama\tmp" ("staging_" + [IO.Path]::GetFileNameWithoutExtension($name))
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    if($f.Extension -match '\.zip$'){ Expand-Archive -LiteralPath $f.FullName -DestinationPath $staging -Force }
    else { Copy-Item -LiteralPath $f.FullName -Destination $staging -Force }
    $files = Get-ChildItem -Path $staging -Recurse -File
    foreach($ff in $files){
      $rel = $ff.FullName.Substring($staging.Length).TrimStart('\','/')
      $target = Join-Path $RepoRoot $rel
      $tDir = [IO.Path]::GetDirectoryName($target); if($tDir){ New-Item -ItemType Directory -Force -Path $tDir | Out-Null }
      if(Is-TextFile $target){
        $content = Get-Content -LiteralPath $ff.FullName -Raw -Encoding UTF8
        Stamp-And-Write $target $content
      } else {
        Copy-Item -LiteralPath $ff.FullName -Destination $target -Force
      }
      $Changed.Value += $target
    }
    break
  }
}

function Git-CommitPush([string]$Repo,[string]$Message,[bool]$NoPush){
  try{
    & git add -A | Out-Null
    $st = (git status --porcelain)
    if([string]::IsNullOrWhiteSpace($st)){ return "no-change" }
    & git commit -m $Message | Out-Null
    if(-not $NoPush){ & git push | Out-Null; return "pushed" } else { return "committed" }
  } catch { return ("git-error: " + $_.Exception.Message) }
}

function Capture-Screenshot([string]$Path){
  try{
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); return $true
  } catch { return $false }
}

function New-Zip([string]$ZipPath,[string[]]$Items){
  if(Test-Path $ZipPath){ Remove-Item $ZipPath -Force }
  $temp = Join-Path "_otokodlama\tmp" ("zip_" + ([IO.Path]::GetFileNameWithoutExtension($ZipPath)))
  if(Test-Path $temp){ Remove-Item $temp -Recurse -Force -EA SilentlyContinue }
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  foreach($i in $Items){
    if(Test-Path $i){
      $dest = Join-Path $temp ([IO.Path]::GetFileName($i))
      Copy-Item -LiteralPath $i -Destination $dest -Recurse -Force
    }
  }
  Compress-Archive -Path (Join-Path $temp '*') -DestinationPath $ZipPath -Force
}

# ---- Workspace ----
$root = Resolve-Root
Set-Location $root
New-Item -ItemType Directory -Force -Path "_otokodlama\out","_otokodlama\inbox","_otokodlama\logs","_otokodlama\reports","_otokodlama\tmp","build" | Out-Null

$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logPath = "_otokodlama\logs\loop_$ts.log"
try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }

# ---- 1) CSV → JSON ----
$tasksJson = "build\tasks.json"
$rows = Convert-TodoCsvToJson -Csv $CsvPath -OutJson $tasksJson
$task = Select-NextTask -rows $rows -Id $TaskId
if(!$task){
  Write-Host "Seçilecek görev bulunamadı (TODO/PENDING)."
  try { Stop-Transcript | Out-Null } catch { }
  return
}
Write-Host ("Seçilen Görev: {0} — {1}" -f $task.id, $task.title)

# ---- 2) AI İstek Paketi ----
$aiReq = @{
  task = $task
  base_url = $BaseUrl
  context = @{
    git_branch    = (git rev-parse --abbrev-ref HEAD) 2>$null
    latest_commit = (git rev-parse --short HEAD) 2>$null
  }
  artifacts = @()
  note = "Read-only paket; AI cevabını _otokodlama/inbox altına ZIP/TXT olarak bırak."
}
$reqPath = "_otokodlama\out\ai_request_$($task.id)_$ts.json"
Write-Utf8 $reqPath (($aiReq | ConvertTo-Json -Depth 8))

$details = Get-ChildItem "_otokodlama\reports" -Recurse -File -Filter "details_*.csv" -EA SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$totals  = Get-ChildItem "_otokodlama\reports" -Recurse -File -Filter "totals_*.csv"  -EA SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# ---- 3) Inbox → Yama Uygula ----
$changed = @()
Apply-AIChangesFromInbox -TaskId $task.id -Inbox "_otokodlama\inbox" -RepoRoot (Get-Location).Path ([ref]$changed)
if((@($changed)).Length -gt 0){
  Write-Host ("AI kaynaklı değişen dosyalar: " + ($changed -join ", "))
  $gitState = Git-CommitPush -Repo $root -Message ("task:{0} apply AI patch" -f $task.id) -NoPush:$NoPush
  Write-Host ("Git: " + $gitState)
}

# ---- 4) Server Sağlığı ----
$serverOk = Ensure-Server -Url $BaseUrl -WaitSeconds $ServerWaitSeconds
if(-not $serverOk){ Write-Warning ("Server erişimi sağlanamadı: {0}/admin/" -f $BaseUrl) }

# ---- 5) Mevcut Playwright Testlerini Koş ----
$testSummary = @{ invoked = $false; exitCode = $null; reportJson = $null; note = $null }
try{
  $testSummary.invoked = $true
  if(-not (Get-Command npm -EA SilentlyContinue)){ throw "npm bulunamadı (Node yok?)." }
  if(Test-Path "package.json"){
    $pkgRaw = Get-Content -LiteralPath "package.json" -Raw -Encoding UTF8
    if($pkgRaw -match '<<<<<<<|=======|>>>>>>>' ){ throw "package.json çatışma işaretleri içeriyor." }
    try{ $null = $pkgRaw | ConvertFrom-Json } catch { throw ("package.json geçersiz JSON: " + $_.Exception.Message) }
  }
  npx playwright test --config="playwright.all.config.cjs" --headed
  $testSummary.exitCode = $LASTEXITCODE
  $r = Get-ChildItem -Recurse -File -Filter "report.json" | Where-Object { $_.FullName -match 'playwright-report[\\/].*data[\\/]report\.json$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($r){ $testSummary.reportJson = $r.FullName }
} catch { $testSummary.note = $_.Exception.Message }

# ---- 6) Artefaktlar ----
$snap = $null
if(-not $NoScreenshot){
  $snap = "_otokodlama\reports\screenshot_$ts.png"
  $okSnap = Capture-Screenshot $snap
  if(-not $okSnap){ $snap = $null }
}
$bundleItems = @($reqPath, $logPath)
if($testSummary.reportJson){ $bundleItems += $testSummary.reportJson }
if($details){ $bundleItems += $details.FullName }
if($totals){  $bundleItems += $totals.FullName }
if($snap){    $bundleItems += $snap }
$zipPath = "_otokodlama\out\bundle_$($task.id)_$ts.zip"
New-Zip -ZipPath $zipPath -Items $bundleItems

# ---- 7) Sonuç Özeti (AI'ye geri paket) ----
$result = @{
  task_id   = $task.id
  title     = $task.title
  base_url  = $BaseUrl
  server_ok = $serverOk
  tests     = $testSummary
  changed_files = $changed
  artifacts = @{
    ai_request = (Resolve-Path $reqPath).Path
    bundle_zip = (Resolve-Path $zipPath).Path
    log        = (Resolve-Path $logPath).Path
    screenshot = if($snap){ (Resolve-Path $snap).Path } else { $null }
  }
  when = $ts
}
$resPath = "_otokodlama\out\ai_result_$($task.id)_$ts.json"
Write-Utf8 $resPath (($result | ConvertTo-Json -Depth 9))

# ---- 8) todolist.csv durum güncelle ----
function Update-TodoStatus([string]$Csv,[string]$Id,[string]$NewStatus,[string]$Note){
  $all = @(Import-Csv -LiteralPath $Csv)
  $hit = $false
  foreach($r in $all){
    if($r.id -eq $Id){
      $r.status = $NewStatus
      if($Note){
        if(-not ($r.PSObject.Properties.Name -contains 'note')){ $r | Add-Member -NotePropertyName note -NotePropertyValue "" }
        $r.note = $Note
      }
      $hit = $true
    }
  }
  if($hit){
    $bak = "$Csv.bak_$ts"
    Copy-Item -LiteralPath $Csv -Destination $bak -Force
    $all | Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding UTF8
  }
}
if($testSummary.invoked -and $testSummary.exitCode -eq 0){
  Update-TodoStatus -Csv $CsvPath -Id $task.id -NewStatus "done" -Note ("OK; bundle: " + (Split-Path $zipPath -Leaf))
} elseif($testSummary.invoked -and $testSummary.exitCode -ne $null){
  Update-TodoStatus -Csv $CsvPath -Id $task.id -NewStatus "needs-work" -Note ("exitCode={0}; {1}" -f $testSummary.exitCode,$testSummary.note)
} else {
  Update-TodoStatus -Csv $CsvPath -Id $task.id -NewStatus "pending" -Note ("not-run: " + $testSummary.note)
}

# ---- Konsol Özeti ----
"=== LOOP ONCE SUMMARY ==="
("Task: {0} — {1}" -f $task.id, $task.title)
("Server OK: {0}" -f $serverOk)
("Tests: invoked={0} exitCode={1} note={2}" -f $testSummary.invoked,$testSummary.exitCode,$testSummary.note)
("Changed files: {0}" -f ((@($changed)).Length))
("Out: {0}" -f (Resolve-Path $resPath))
("Bundle: {0}" -f (Resolve-Path $zipPath))

try { Stop-Transcript | Out-Null } catch { }
# exit YOK
