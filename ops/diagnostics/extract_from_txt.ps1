param(
  [string]$Repo=".",
  [string]$ReportsDir="_otokodlama\reports"
)
chcp 65001 > $null
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding            = [Text.UTF8Encoding]::new($false)
Set-StrictMode -Version Latest; $ErrorActionPreference="Stop"
$repo = Resolve-Path $Repo
$reportsRoot = Join-Path $repo $ReportsDir
$dash        = Join-Path $reportsRoot "dashboard"
if (-not (Test-Path $dash)) { New-Item -ItemType Directory -Force -Path $dash | Out-Null }
$txt = Get-ChildItem $reportsRoot -File -Filter 'universal_findings_*.txt' |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $txt) {
  $empty = Join-Path $dash ("details_" + (Get-Date -Format yyyyMMdd-HHmmss) + ".csv")
  'Section,Status,Message' | Out-File -FilePath $empty -Encoding UTF8
  Write-Host "[DETAILS] TXT yok; boş başlıklı CSV yazıldı: $empty"
  exit 0
}
$stamp     = ([IO.Path]::GetFileNameWithoutExtension($txt.Name)) -replace '^universal_findings_',''
$details   = Join-Path $dash ("details_" + $stamp + ".csv")
$section = 'HEADER'
$rows = New-Object 'System.Collections.Generic.List[object]'
Get-Content $txt.FullName | ForEach-Object {
  $ln = $_
  if ($ln -match '^\s*===\s*(.+?)\s*===\s*$') { $section = $Matches[1]; return }
  if ($ln -match '^\s*\[(PASS|WARN|FAIL)\]\s+(.*)$') {
    $status = $Matches[1]; $msg = $Matches[2]
    if ($status -ne 'PASS') {
      $rows.Add([pscustomobject]@{ Section=$section; Status=$status; Message=$msg })
    }
  }
}
if ($rows.Count -gt 0) {
  $rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $details
  Write-Host "[DETAILS] Yazıldı: $details (satır: $($rows.Count))"
} else {
  'Section,Status,Message' | Out-File -FilePath $details -Encoding UTF8
  Write-Host "[DETAILS] Sadece başlık yazıldı (uyarı/başarısızlık bulunamadı): $details"
}