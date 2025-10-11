param(
  [string]$Repo       = ".",
  [string]$ReportsDir = "_otokodlama\reports",
  [string]$BundleDir  = "_otokodlama\bundle",
  [string]$CsvPath    = "tasks_template.csv",
  [string]$TasksJson  = "build\tasks.json",
  [switch]$PatchReportCodes
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function First-NonEmpty { param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Values)
  foreach ($v in $Values) { if ($null -ne $v) { $s=[string]$v; if ($s.Trim().Length -gt 0) { return $s } } } return "" }
function Ensure-Dir([string]$Path) { $p = (Split-Path -Parent $Path); if ($p -and -not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Get-Prop($obj, [string]$name, $default="") {
  if ($null -eq $obj) { return $default }; $has = $obj.PSObject.Properties[$name]
  if ($has -and $null -ne $has.Value -and ([string]$has.Value).Trim().Length -gt 0) { return $has.Value } return $default }
$repo = Resolve-Path $Repo; Set-Location $repo
$ts   = (Get-Date).ToString("yyyyMMdd-HHmmss")
$reportsRoot = Join-Path $repo $ReportsDir
$dashboard   = Join-Path $reportsRoot "dashboard"
$notifyDir   = Join-Path $reportsRoot "notify"
$bundleRoot  = Join-Path $repo $BundleDir
function Resolve-UnderRepo([string]$p){ if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $repo $p } }
$csvFull   = Resolve-UnderRepo $CsvPath
$tasksFull = Resolve-UnderRepo $TasksJson
Ensure-Dir $tasksFull
if (-not (Test-Path $notifyDir)) { New-Item -ItemType Directory -Force -Path $notifyDir | Out-Null }
if (-not (Test-Path $bundleRoot)) { New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null }
function Convert-TasksCsvToJson {
  param([string]$Csv, [string]$OutJson)
  if (-not (Test-Path $Csv)) {
    Write-Host "[CSV→JSON] $Csv yok, boş tasks.json yazılıyor" -ForegroundColor Yellow
    $empty = @{ generated_at = (Get-Date).ToUniversalTime().ToString("s") + "Z"; source="universal_planning"; items=@() }
    Ensure-Dir $OutJson; ($empty | ConvertTo-Json -Depth 10) | Set-Content -Path $OutJson -Encoding UTF8; return
  }
  $bytes = [IO.File]::ReadAllBytes($Csv)
  if ($bytes.Length -ge 3 -and $bytes[0]-eq 0xEF -and $bytes[1]-eq 0xBB -and $bytes[2]-eq 0xBF) {
    $text = [Text.UTF8Encoding]::new($false).GetString($bytes,3,$bytes.Length-3)
  } else { $text = [Text.UTF8Encoding]::new($false).GetString($bytes) }
  $firstLine = ($text -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
  if ($null -eq $firstLine -or ($firstLine -notmatch '(^|,)id(,|$)') -or ($firstLine -notmatch '(^|,)title(,|$)')) {
    Write-Host "[CSV→JSON] Uyarı: id/title başlıkları beklenen biçimde değil" -ForegroundColor Yellow }
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
  Ensure-Dir $OutJson; ($doc | ConvertTo-Json -Depth 10) | Set-Content -Path $OutJson -Encoding UTF8
  Write-Host "[CSV→JSON] Yazıldı: $OutJson"
}
function Merge-FindingsIntoTasks {
  param([string]$DetailsCsv, [string]$TasksJsonPath)
  if (Test-Path $TasksJsonPath) {
    try { $tasksObj = Get-Content $TasksJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "[MERGE] $TasksJsonPath parse edilemedi: $($_.Exception.Message)" }
  } else { $tasksObj = [ordered]@{ generated_at=(Get-Date).ToUniversalTime().ToString("s")+"Z"; source="universal_planning"; items=@() } }
  $items = New-Object 'System.Collections.Generic.List[object]'; if ($tasksObj.items) { $items.AddRange([object[]]$tasksObj.items) }
  $rows = @(); if (Test-Path $DetailsCsv) { try { $rows = Import-Csv $DetailsCsv } catch { $rows = @() } }
  $existing = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($it in $items) {
    $id  = Get-Prop $it 'id' ""; $ttl = Get-Prop $it 'title' ""; $src = Get-Prop $it 'source' "csv"
    if ($id -and $id.Trim().Length -gt 0) { [void]$existing.Add(("ID::" + $id.Trim().ToLower())) }
    else { [void]$existing.Add(("TT::" + $ttl.Trim().ToLower() + "::" + $src)) }
  }
  foreach ($r in $rows) {
    $sec  = First-NonEmpty (Get-Prop $r 'Section') ""; $msg=First-NonEmpty (Get-Prop $r 'Message') ""
    $stat = (First-NonEmpty (Get-Prop $r 'Status') "").ToUpper()
    if ($msg.Trim().Length -eq 0) { continue }
    $hRaw  = ($sec + "::" + $msg).Trim().ToLower()
    $code  = (if ($stat -eq "FAIL") { "UNIV-FAIL" } elseif ($stat -eq "WARN") { "UNIV-WARN" } else { "UNIV-NOTE" })
    $title = ("[{0}] {1} - {2}" -f $code,$sec,$msg); $key = "TT::" + $hRaw + "::universal_findings"
    if (-not $existing.Contains($key)) {
      $severity = if ($stat -eq "FAIL") { "high" } elseif ($stat -eq "WARN") { "medium" } else { "low" }
      $items.Add([ordered]@{ id=""; title=$title.Substring(0,[Math]::Min(200,$title.Length)); severity=$severity; area="aggregation";
        evidence=$sec; timestamp=(Get-Date).ToUniversalTime().ToString("s")+"Z"; status="todo";
        steps=@("Kaynak: dashboard/details_*.csv","Tekil anahtar: section+message"); source="universal_findings" })
      [void]$existing.Add($key)
    }
  }
  $tasksObj.items = $items; Ensure-Dir $TasksJsonPath
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
function Patch-ReportUniversal-Codes {
  param([string]$DiagnosticsDir)
  $file = Join-Path $DiagnosticsDir "report_universal.ps1"
  if (-not (Test-Path $file)) { Write-Host "[PATCH] report_universal.ps1 yok, atlandı" -ForegroundColor Yellow; return }
  $raw = Get-Content $file -Raw
  if ($raw -match "UNIV-HEAD-001") { Write-Host "[PATCH] Zaten yamanmış, atlandı"; return }
  $patched = $raw `
    -replace 'UX-Result "Başlık \(H1/heading\)" "FAIL"',     'UX-Result "UNIV-HEAD-001 Başlık (H1/heading)" "FAIL"' `
    -replace 'UX-Result "Başlık \(H1/heading\)" "PASS"',     'UX-Result "UNIV-HEAD-000 Başlık (H1/heading)" "PASS"' `
    -replace 'UX-Result "Heading/#content-start" "WARN"',    'UX-Result "UNIV-ROUT-001 Heading/#content-start" "WARN"' `
    -replace 'UX-Result "Heading/#content-start" "PASS"',    'UX-Result "UNIV-ROUT-000 Heading/#content-start" "PASS"' `
    -replace 'UX-Result "page\.response\(\) imzası" "FAIL"', 'UX-Result "UNIV-FORM-001 page.response() imzası" "FAIL"' `
    -replace 'UX-Result "page\.response\(\) imzası" "PASS"', 'UX-Result "UNIV-FORM-000 page.response() imzası" "PASS"'
  [IO.File]::WriteAllText($file, $patched, [Text.UTF8Encoding]::new($false))
  Write-Host "[PATCH] report_universal.ps1 → UNIV-XXXX kodları eklendi"
}
# ---- ÇALIŞTIRMA SIRASI ----
Convert-TasksCsvToJson -Csv $csvFull -OutJson $tasksFull
$details = $null; $totals = $null
if (Test-Path $dashboard) {
  $details = Get-ChildItem $dashboard -File -Filter "details_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $totals  = Get-ChildItem $dashboard -File -Filter "totals_*.csv"  | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($details) { Merge-FindingsIntoTasks -DetailsCsv $details.FullName -TasksJsonPath $tasksFull }
$detailsPath = if ($details) { $details.FullName } else { $null }
if ($totals)  { Write-NotifySummary -TotalsCsv $totals.FullName -DetailsCsv $detailsPath -OutDir $notifyDir }
Include-Extras-ToBundle -BundleRoot $bundleRoot -ReportsRoot $reportsRoot -TasksFile $tasksFull
Write-Host "`n[OK] Post-process tamamlandı." -ForegroundColor Green