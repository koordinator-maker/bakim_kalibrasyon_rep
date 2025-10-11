param(
  [string]$OutDir    = "_otokodlama\out",
  [string]$ReportDir = "_otokodlama\reports",
  [string]$Include   = "*.json",
  [int]   $MaxErrLen = 200
)

function New-DirIfMissing($p) { if (!(Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
New-DirIfMissing $ReportDir

function Shorten([string]$s, [int]$n) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "" }
  $flat = ($s -replace "\s+"," ").Trim()
  if ($flat.Length -le $n) { return $flat }
  return $flat.Substring(0,[Math]::Min($n,$flat.Length))
}

function Classify-Failure($step) {
  $cmd = "$($step.cmd)".ToUpper()
  $arg = [string]$step.arg
  $err = [string]$step.error
  $url = [string]$step.url

  if ($cmd -eq "AUTOVALIDATE") {
    $parts = @()
    if ($step.ok_words  -eq $false) { $parts += "kelime-recall" }
    if ($step.ok_visual -eq $false) { $parts += "görsel-benzerlik" }
    if ($step.ok_selects -eq $false){ $parts += "select-kontrolü" }
    if ($parts.Count -eq 0) { $parts = @("autovalidate") }
    return "autovalidate: " + ($parts -join "+")
  }

  if ($err -match "ERR_TOO_MANY_REDIRECTS") { return "redirect-loop" }
  if ($url -like "chrome-error://*")       { return "browser/navigation-error" }
  if ($err -match "ERR_CONNECTION_REFUSED") { return "server-down" }
  if ($err -match "403|Forbidden")          { return "403-forbidden" }
  if ($err -match "401|Unauthorized")       { return "401-unauthorized" }

  if ($err -match "TimeoutError: Page\.wait_for_selector") {
    if ($arg -match "table#result_list")                     { return "liste-boş/kayıt-yok/selector-değişti" }
    if ($arg -match "form#changelist-search|input#searchbar"){ return "arama-çubuğu-bulunamadı" }
    if ($arg -match "form#equipment_form")                   { return "form-yüklenmedi" }
    if ($arg -match "\.messagelist")                         { return "başarı-mesajı-yok" }
    return "selector-timeout"
  }

  if ($cmd -eq "CLICK" -and $err -match "not visible|detached|is not visible") { return "click-mümkün-değil" }
  return "diğer"
}

# Dosya listesi (Include destekli)
$rows = @()
$files = @()
$patterns = $Include -split '[,; ]+' | Where-Object { $_ -and $_.Trim() -ne "" }
if ($patterns.Count -eq 0) { $patterns = @("*.json") }
foreach ($p in $patterns) { $files += Get-ChildItem (Join-Path $OutDir $p) -ErrorAction SilentlyContinue }
if ($files.Count -eq 0)   { $files  = Get-ChildItem (Join-Path $OutDir "*.json") -ErrorAction SilentlyContinue }
$files = $files | Sort-Object LastWriteTime

foreach ($f in $files) {
  # JSON'u UTF-8 olarak oku; gerekirse .NET fallback
  try {
    $raw = Get-Content $f.FullName -Raw -Encoding UTF8
  } catch {
    $raw = [IO.File]::ReadAllText($f.FullName, [Text.UTF8Encoding]::new($true))
  }
  try {
    $j = $raw | ConvertFrom-Json
  } catch {
    $rows += [pscustomobject]@{
      Flow=[IO.Path]::GetFileNameWithoutExtension($f.Name); Pass=$false; FirstFailStep=''; Cmd='';
      Reason='json-parse-error'; ErrorSnippet=(Shorten "$($_.Exception.Message)" $MaxErrLen);
      Url=''; Recall=''; VisualSim=''; OkWords=''; OkVisual=''; OkSelects=''; MissingCount='';
      Log=([IO.Path]::ChangeExtension($f.FullName,'log'))
    }
    continue
  }

  if ($null -eq $j.ok -or $null -eq $j.results) {
    $rows += [pscustomobject]@{
      Flow=[IO.Path]::GetFileNameWithoutExtension($f.Name); Pass=$false; FirstFailStep=''; Cmd='';
      Reason='schema-mismatch'; ErrorSnippet=''; Url=''; Recall=''; VisualSim=''; OkWords=''; OkVisual=''; OkSelects=''; MissingCount='';
      Log=([IO.Path]::ChangeExtension($f.FullName,'log'))
    }
    continue
  }

  $flow  = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $pass  = [bool]$j.ok
  $steps = @($j.results)
  $firstFail = $steps | Where-Object { $_.ok -ne $true } | Select-Object -First 1

  # Autovalidate metrikleri (varsa)
  $recall=''; $visual=''; $okw=''; $okv=''; $oks=''; $miss=''
  foreach ($s in $steps) {
    if ("$($s.cmd)".ToUpper() -eq "AUTOVALIDATE") {
      $recall=$s.recall; $visual=$s.visual_sim; $okw=$s.ok_words; $okv=$s.ok_visual; $oks=$s.ok_selects; $miss=$s.missing_count
    }
  }

  if (-not $firstFail -and -not $pass) {
    $toolErr = ""; try { $toolErr = [string]$j.tool_error } catch {}
    $rows += [pscustomobject]@{
      Flow=$flow; Pass=$pass; FirstFailStep=''; Cmd=''; Reason='tool-error/no-steps';
      ErrorSnippet=(Shorten $toolErr $MaxErrLen); Url='';
      Recall=$recall; VisualSim=$visual; OkWords=$okw; OkVisual=$okv; OkSelects=$oks; MissingCount=$miss;
      Log=([IO.Path]::ChangeExtension($f.FullName,'log'))
    }
    continue
  }

  if ($firstFail) {
    $rows += [pscustomobject]@{
      Flow=$flow; Pass=$pass; FirstFailStep=$firstFail.i; Cmd=$firstFail.cmd;
      Reason=(Classify-Failure $firstFail); ErrorSnippet=(Shorten([string]$firstFail.error, $MaxErrLen));
      Url=$firstFail.url; Recall=$recall; VisualSim=$visual; OkWords=$okw; OkVisual=$okv; OkSelects=$oks; MissingCount=$miss;
      Log=([IO.Path]::ChangeExtension($f.FullName,'log'))
    }
  } else {
    $lastUrl = ''; if ($steps.Count -gt 0) { $lastUrl = $steps[-1].url }
    $rows += [pscustomobject]@{
      Flow=$flow; Pass=$pass; FirstFailStep=''; Cmd=''; Reason='passed'; ErrorSnippet=''; Url=$lastUrl;
      Recall=$recall; VisualSim=$visual; OkWords=$okw; OkVisual=$okv; OkSelects=$oks; MissingCount=$miss;
      Log=([IO.Path]::ChangeExtension($f.FullName,'log'))
    }
  }
}

# Çıktılar
$csvPath  = Join-Path $ReportDir "crud_summary.csv"
$jsonPath = Join-Path $ReportDir "crud_summary.json"
$mdPath   = Join-Path $ReportDir "crud_summary.md"

New-DirIfMissing $ReportDir
$rows | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
$rows | ConvertTo-Json -Depth 8 | Out-File $jsonPath -Encoding utf8

$passCount = ($rows | Where-Object {$_.Pass -eq $true}).Count
$failCount = ($rows | Where-Object {$_.Pass -ne $true}).Count
$byReason  = $rows | Group-Object Reason | Sort-Object Count -Descending

$md = @()
$md += "# Admin PW Koşu Özeti"
$md += ""
$md += "*Toplam:* $($rows.Count)  |  *Geçti:* $passCount  |  *Kaldı:* $failCount"
$md += ""
$md += "## Hata Dağılımı"
foreach ($g in $byReason) { $md += "- **$($g.Name)**: $($g.Count)" }
$md += ""
$md += "## Akışlar"
$md += ""
$md += "| Flow | Pass | Reason | FirstFailStep | Cmd | Recall | VisualSim | OkWords | OkVisual | OkSelects | Missing | ErrorSnippet | Log |"
$md += "|------|------|--------|---------------|-----|--------|-----------|---------|----------|-----------|---------|--------------|-----|"
foreach ($r in $rows) {
  $md += "| $($r.Flow) | $($r.Pass) | $($r.Reason) | $($r.FirstFailStep) | $($r.Cmd) | $($r.Recall) | $($r.VisualSim) | $($r.OkWords) | $($r.OkVisual) | $($r.OkSelects) | $($r.MissingCount) | $(($r.ErrorSnippet -replace '\|','/')) | $($r.Log) |"
}
$md -join "`r`n" | Out-File $mdPath -Encoding utf8

Write-Host "== PW RAPORU ==" -ForegroundColor Cyan
"{0,-38} {1,-6} {2,-24} {3,-5} {4}" -f "Flow","Pass","Reason","Step","Cmd"
foreach ($r in $rows) {
  "{0,-38} {1,-6} {2,-24} {3,-5} {4}" -f $r.Flow, $r.Pass, (Shorten $r.Reason 24), $r.FirstFailStep, $r.Cmd
}
Write-Host ""
Write-Host ("CSV : " + $csvPath)
Write-Host ("JSON: " + $jsonPath)
Write-Host ("MD  : " + $mdPath)

