param(
  [string]$Repo = ".",
  [string]$ReportsDir = "_otokodlama\reports",
  [string]$SuiteName = "UniversalFindings",
  [string]$OutputDir = "_otokodlama\reports\junit",
  [switch]$GateOnFail = $true,
  [switch]$GateOnWarn = $false,
  [switch]$WarnAsSkip = $true,
  [switch]$DoExit = $false
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Get-OrDefault([string]$value, [string]$fallback){
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { $fallback } else { $value }
}
$repo = Resolve-Path $Repo; Set-Location $repo
$reportsRoot = Join-Path $repo $ReportsDir
$dashDir     = Join-Path $reportsRoot "dashboard"
if (-not (Test-Path $dashDir)) { Write-Host "[JUnit] Dashboard dizini yok: $dashDir" -ForegroundColor Yellow; $global:LASTEXITCODE = 0; return }
$totals  = Get-ChildItem $dashDir -File -Filter "totals_*.csv"  | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$details = Get-ChildItem $dashDir -File -Filter "details_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $totals)  { Write-Host "[JUnit] totals_*.csv bulunamadı."  -ForegroundColor Yellow; $global:LASTEXITCODE = 0; return }
if (-not $details) { Write-Host "[JUnit] details_*.csv bulunamadı." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; return }
$totObj = Import-Csv $totals.FullName | Select-Object -First 1
[int]$pass = $totObj.PASS
[int]$warn = $totObj.WARN
[int]$fail = $totObj.FAIL
$timestamp = $totObj.Timestamp
$fileName  = $totObj.File
try { $detailRows = Import-Csv $details.FullName } catch { $detailRows = @() }
$detailRows = $detailRows | Where-Object { $_.Section -or $_.Status -or $_.Message }
$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
$outDir = Join-Path $repo $OutputDir
$null = New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outXml = Join-Path $outDir ("universal_junit_" + $ts + ".xml")
$tests    = [math]::Max(0, $fail + $warn)
$failures = [math]::Max(0, $fail)
$skipped  = if($WarnAsSkip){ [math]::Max(0, $warn) } else { 0 }
$xml  = New-Object System.Xml.XmlDocument
$decl = $xml.CreateXmlDeclaration("1.0","UTF-8",$null); $xml.AppendChild($decl) | Out-Null
$root = $xml.CreateElement("testsuite")
$root.SetAttribute("name", $SuiteName)
$root.SetAttribute("tests", $tests.ToString())
$root.SetAttribute("failures", $failures.ToString())
$root.SetAttribute("skipped", $skipped.ToString())
$root.SetAttribute("time", "0")
$root.SetAttribute("timestamp", (Get-Date).ToString("o"))
$xml.AppendChild($root) | Out-Null
$props = $xml.CreateElement("properties"); $root.AppendChild($props) | Out-Null
function Add-Prop([string]$k,[string]$v){ $p=$xml.CreateElement("property"); $p.SetAttribute("name",$k); $p.SetAttribute("value",$v); $props.AppendChild($p) | Out-Null }
Add-Prop "universal.timestamp" $timestamp
Add-Prop "universal.file"      $fileName
Add-Prop "universal.pass"      $pass
Add-Prop "universal.warn"      $warn
Add-Prop "universal.fail"      $fail
$idx = 0
foreach($row in $detailRows){
  $idx++
  $className = Get-OrDefault $row.Section "Universal"
  $nameLabel = ("{0}-{1}" -f (Get-OrDefault $row.Status "NOTE"), $idx)
  $msg       = Get-OrDefault $row.Message "No message"
  $case = $xml.CreateElement("testcase")
  $case.SetAttribute("classname", $className)
  $case.SetAttribute("name", $nameLabel)
  $case.SetAttribute("time", "0")
  if ($row.Status -eq "FAIL") {
    $f = $xml.CreateElement("failure"); $f.SetAttribute("message", $msg); $f.InnerText = $msg; $case.AppendChild($f) | Out-Null
  } elseif ($row.Status -eq "WARN" -and $WarnAsSkip) {
    $s = $xml.CreateElement("skipped"); $s.SetAttribute("message", $msg); $case.AppendChild($s) | Out-Null
  }
  $root.AppendChild($case) | Out-Null
}
$sysout = $xml.CreateElement("system-out"); $sysout.InnerText = ("Summary: PASS={0} WARN={1} FAIL={2} | Source={3}" -f $pass,$warn,$fail,$fileName); $root.AppendChild($sysout) | Out-Null
$xml.Save($outXml)
Write-Host ("[JUnit] XML: " + $outXml) -ForegroundColor Cyan
Write-Host ("[JUnit] Totals: PASS={0} WARN={1} FAIL={2}" -f $pass,$warn,$fail)
$exitCode = 0
if ($GateOnFail -and $fail -gt 0) {
  $exitCode = 2
} elseif ($GateOnWarn -and $warn -gt 0) {
  $exitCode = 3
}
$gateTxt = Join-Path $outDir ("gate_result_" + $ts + ".txt")
"ExitCode=$exitCode`nPASS=$pass`nWARN=$warn`nFAIL=$fail`nXML=$outXml" | Out-File -FilePath $gateTxt -Encoding UTF8
$global:LASTEXITCODE = $exitCode
if ($exitCode -ne 0) { Write-Host ("[JUnit] Gate triggered. ExitCode=" + $exitCode + " (terminal açık)") -ForegroundColor Yellow }
else { Write-Host "[JUnit] Gate not triggered. ExitCode=0 (terminal açık)" -ForegroundColor Green }
if ($DoExit) { exit $exitCode }
