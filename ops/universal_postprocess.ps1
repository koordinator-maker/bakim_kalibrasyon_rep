param(
  [string]$Repo       = ".",
  [string]$ReportsDir = "_otokodlama\reports",
  [string]$BundleDir  = "_otokodlama\bundle",
  [string]$CsvPath    = "tasks_template.csv",
  [string]$TasksJson  = "build\tasks.json"
)
chcp 65001 > $null
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding            = [Text.UTF8Encoding]::new($false)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function First-NonEmpty {
  param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Values)
  foreach ($v in $Values) { if ($null -ne $v) { $s=[string]$v; if ($s.Trim().Length -gt 0) { return $s } } }
  return ""
}
function Ensure-Dir([string]$Path) {
  $p = (Split-Path -Parent $Path)
  if ($p -and -not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Get-Prop($obj, [string]$name, $default="") {
  if ($null -eq $obj) { return $default }
  $has = $obj.PSObject.Properties[$name]
  if ($has -and $null -ne $has.Value) { $s=[string]$has.Value; if ($s.Trim().Length -gt 0) { return $has.Value } }
  return $default
}
$repo = Resolve-Path $Repo
Set-Location $repo
$reportsRoot = Join-Path $repo $ReportsDir
$dashboard   = Join-Path $reportsRoot "dashboard"
$notifyDir   = Join-Path $reportsRoot "notify"
$bundleRoot  = Join-Path $repo $BundleDir
function Resolve-UnderRepo([string]$p){ if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $repo $p } }
$csvFull   = Resolve-UnderRepo $CsvPath
$tasksFull = Resolve-UnderRepo $TasksJson
if (-not (Test-Path $notifyDir)) { New-Item -ItemType Directory -Force -Path $notifyDir | Out-Null }
if (-not (Test-Path $bundleRoot)) { New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null }
function Convert-TasksCsvToJson {
  param([string]$Csv, [string]$OutJson)
  if (-not (Test-Path $Csv)) {
    Write-Host "[CSV→JSON] $Csv yok, boş tasks.json yazılıyor" -ForegroundColor Yellow
    $empty = @{ generated_at = (Get-Date).ToUniversalTime().ToString("s") + "Z"; source="universal_planning"; items=@() }
    Ensure-Dir $OutJson
    ($empty | ConvertTo-Json -Depth 10) | Set-Content -Path $OutJson -Encoding UTF8
    return
  }
  $bytes = [IO.File]::ReadAllBytes($Csv)
  if ($bytes.Length -ge 3 -and $bytes[0]-eq 0xEF -and $bytes[1]-eq 0xBB -and $bytes[2]-eq 0xBF) {
    $text = [Text.UTF8Encoding]::new($false).GetString($bytes,3,$bytes.Length-3)
  } else {
    $text = [Text.UTF8Encoding]::new($false).GetString($bytes)
  }
  $firstLine = ($text -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
  if ($null -eq $firstLine -or ($firstLine -notmatch '(^|,)id(,|$)') -or ($firstLine -notmatch '(^|,)title(,|$)')) {
    Write-Host "[CSV→JSON] Uyarı: id/title başlıkları beklenen biçimde değil" -ForegroundColor Yellow
  }
  try { $rows = ConvertFrom-Csv -InputObject $text } catch { throw "[CSV→JSON] CSV parse hatası: $($_.Exception.Message)" }
  $doc = [ordered]@{ generated_at=(Get-Date).ToUniversalTime().ToString("s")+"Z"; source="csv_template"; items=@() }
  foreach ($r in $rows) {
    $id    = First-NonEmpty (Get-Prop $r 'id') (Get-Prop $r 'ID') (Get-Prop $r 'task_id')
    $title = First-NonEmpty (Get-Prop $r 'title') (Get-Prop $r 'TITLE') (Get-Prop $r 'name')
    $sev   = First-NonEmpty (Get-Prop $r 'severity') "medium"
    $area  = First-NonEmpty (Get-Prop $r 'area') "pipeline"
    $evd   = First-NonEmpty (Get-Prop $r 'evidence') ""
    $tsmp  = First-NonEmpty (Get-Prop $r 'timestamp') ""
    $stat  = First-NonEmpty (Get-Prop $r 'status') "todo"
    $doc.items += [ordered]@{ id=$id; title=$title; severity=$sev; area=$area; evidence=$evd; timestamp=$tsmp; status=$stat; steps=@(); source="csv" }
  }
  Ensure-Dir $OutJson
  ($doc | ConvertTo-Json -Depth 10) | Set-Content -Path $OutJson -Encoding UTF8
  Write-Host "[CSV→JSON] Yazıldı: $OutJson"
}
function Merge-FindingsIntoTasks {
  param([string]$DetailsCsv, [string]$TasksJsonPath)
  if (Test-Path $TasksJsonPath) {
    try { $tasksObj = Get-Content $TasksJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "[MERGE] $TasksJsonPath parse edilemedi: $($_.Exception.Message)" }
  } else {
    $tasksObj = [ordered]@{ generated_at=(Get-Date).ToUniversalTime().ToString("s")+"Z"; source="universal_planning"; items=@() }
  }
  $items = New-Object 'System.Collections.Generic.List[object]'
  if ($tasksObj.items) { $items.AddRange([object[]]$tasksObj.items) }
  # 1) details dosyasını belirle
  $detailsFile = $DetailsCsv
  if ([string]::IsNullOrWhiteSpace($detailsFile) -or -not (Test-Path $detailsFile)) {
    if (Test-Path $dashboard) {
      $d = Get-ChildItem $dashboard -File -Filter 'details_*.csv' |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($d) { $detailsFile = $d.FullName }
    }
  }
  # 2) CSV oku
  $rows = @()
  if ($detailsFile -and (Test-Path $detailsFile)) {
    try { $rows = Import-Csv $detailsFile } catch { $rows = @() }
  }
  # 3) Fallback: CSV boşsa TXT parse et
  $needsFallback = $true
  if ($rows -and $rows.Count -gt 0) { $needsFallback = $false }
  if ($needsFallback) {
    $latestTxt = $null
    if (Test-Path $reportsRoot) {
      $latestTxt = Get-ChildItem $reportsRoot -File -Filter 'universal_findings_*.txt' |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if ($latestTxt) {
      $section = 'HEADER'
      $tmpRows = New-Object 'System.Collections.Generic.List[object]'
      Get-Content $latestTxt.FullName | ForEach-Object {
        $ln = $_
        if ($ln -match '^\s*===\s*(.+?)\s*===\s*$') { $section = $Matches[1]; return }
        if ($ln -match '^\s*\[(PASS|WARN|FAIL)\]\s+(.*)$') {
          $status = $Matches[1]; $msg = $Matches[2]
          if ($status -ne 'PASS') {
            $tmpRows.Add([pscustomobject]@{ Section=$section; Status=$status; Message=$msg })
          }
        }
      }
      if ($tmpRows.Count -gt 0) { $rows = $tmpRows }
    }
  }
  # 4) mevcut anahtarlar
  $existing = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($it in $items) {
    $id  = Get-Prop $it 'id' ""
    $ttl = Get-Prop $it 'title' ""
    $src = Get-Prop $it 'source' "csv"
    if ($id -and $id.Trim().Length -gt 0) { [void]$existing.Add(("ID::" + $id.Trim().ToLower())) }
    else { [void]$existing.Add(("TT::" + $ttl.Trim().ToLower() + "::" + $src)) }
  }
  # 5) satırları görevleştir
  foreach ($r in $rows) {
    $sec  = Get-Prop $r 'Section' ""
    $msg  = Get-Prop $r 'Message' ""
    $stat = ([string](Get-Prop $r 'Status' "")).ToUpper()
    if ([string]::IsNullOrWhiteSpace($msg)) { continue }
    $hRaw = ($sec + "::" + $msg).Trim().ToLower()
    $key  = "TT::" + $hRaw + "::universal_findings"
    if (-not $existing.Contains($key)) {
      $code = "UNIV-NOTE"; if ($stat -eq "FAIL") { $code = "UNIV-FAIL" } elseif ($stat -eq "WARN") { $code = "UNIV-WARN" }
      $severity = "low";   if ($stat -eq "FAIL") { $severity = "high" }  elseif ($stat -eq "WARN") { $severity = "medium" }
      $title = ("[{0}] {1} - {2}" -f $code,$sec,$msg)
      $items.Add([ordered]@{
        id        = ""
        title     = $title.Substring(0,[Math]::Min(200,$title.Length))
        severity  = $severity
        area      = "aggregation"
        evidence  = $sec
        timestamp = (Get-Date).ToUniversalTime().ToString("s") + "Z"
        status    = "todo"
        steps     = @("Kaynak: dashboard/details_*.csv","Tekil anahtar: section+message")
        source    = "universal_findings"
      })
      [void]$existing.Add($key)
    }
  }
  # 6) yaz
  $tasksObj.items = $items
  $parent = Split-Path -Parent $TasksJsonPath
  if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  ($tasksObj | ConvertTo-Json -Depth 10) | Set-Content -Path $TasksJsonPath -Encoding UTF8
  Write-Host "[MERGE] Birleşti → $TasksJsonPath (Toplam: $($items.Count))"
}
function Write-NotifySummary {
  param([string]$TotalsCsv, [string]$DetailsCsv, [string]$OutDir)
  $tot = $null; if (Test-Path $TotalsCsv) { try { $tot = Import-Csv $TotalsCsv | Select-Object -First 1 } catch { $tot = $null } }
  if (-not $tot) { Write-Host "[NOTIFY] totals CSV yok/okunamadı, atlandı." -ForegroundColor Yellow; return }
  $lines = @(); if ($DetailsCsv -and (Test-Path $DetailsCsv)) { try { $lines = Import-Csv $DetailsCsv } catch { $lines = @() } }
  $top = $lines | Where-Object { $_.Status -in @("FAIL","WARN") } | Select-Object Section,Status,Message -First 5
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("UNIVERSAL SUMMARY - $(Get-Date -Format s)")
  [void]$sb.AppendLine("Report: $($tot.File)")
  [void]$sb.AppendLine(("Totals: PASS={0} WARN={1} FAIL={2}" -f $tot.PASS,$tot.WARN,$tot.FAIL))
  [void]$sb.AppendLine(""); [void]$sb.AppendLine("Top Findings:")
  if ($top) { foreach($t in $top){ [void]$sb.AppendLine((" - [{0}] {1}: {2}" -f $t.Status,$t.Section,$t.Message)) } }
  else { [void]$sb.AppendLine(" - (yok)") }
  $outFile = Join-Path $OutDir ("summary_" + (Get-Date).ToString("yyyyMMdd-HHmmss") + ".txt")
  [IO.File]::WriteAllText($outFile, $sb.ToString(), [Text.UTF8Encoding]::new($false))
  Write-Host "[NOTIFY] $outFile"
}
function Include-Extras-ToBundle {
  param([string]$BundleRoot, [string]$ReportsRoot, [string]$TasksFile)
  $bundles = Get-ChildItem $BundleRoot -File -Filter "bundle_*.zip" | Sort-Object LastWriteTime -Descending
  if (-not $bundles) { Write-Host "[BUNDLE] bundle_*.zip bulunamadı (atlandı)" -ForegroundColor Yellow; return }
  $zipPath = $bundles[0].FullName
  $temp = Join-Path $BundleRoot ("__temp_unpack_" + [Guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Force -Path $temp | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $temp)
  $destTasks = Join-Path $temp "build\tasks.json"; Ensure-Dir $destTasks
  if (Test-Path $TasksFile) { Copy-Item $TasksFile -Destination $destTasks -Force }
  $srcNotify = Join-Path $ReportsRoot "notify"
  if (Test-Path $srcNotify) {
    $destNotify = Join-Path $temp "_otokodlama\reports\notify"
    if (-not (Test-Path $destNotify)) { New-Item -ItemType Directory -Force -Path $destNotify | Out-Null }
    Copy-Item $srcNotify\* -Destination $destNotify -Recurse -Force
  }
  Remove-Item $zipPath -Force
  [System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $zipPath)
  Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "[BUNDLE] Güncellendi: $zipPath"
}
# ---- AKIŞ ----
Convert-TasksCsvToJson -Csv $csvFull -OutJson $tasksFull
$details = $null; $totals = $null
if (Test-Path $dashboard) {
  $details = Get-ChildItem $dashboard -File -Filter "details_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $totals  = Get-ChildItem $dashboard -File -Filter "totals_*.csv"  | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
$detailsPath = $null; if ($details) { $detailsPath = $details.FullName }
Merge-FindingsIntoTasks -DetailsCsv $detailsPath -TasksJsonPath $tasksFull
if ($totals) { Write-NotifySummary -TotalsCsv $totals.FullName -DetailsCsv $detailsPath -OutDir $notifyDir }
Include-Extras-ToBundle -BundleRoot $bundleRoot -ReportsRoot $reportsRoot -TasksFile $tasksFull
Write-Host "`n[OK] Post-process tamamlandı." -ForegroundColor Green