param(
  [string]$TaskId = "UH001",
  [string]$CsvPath = "todolist.csv",
  [string]$ResultJson,
  [double]$MinScore = 0.9
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
if(-not (Test-Path $CsvPath)){ throw "todolist.csv yok: $CsvPath" }
if(-not (Test-Path $ResultJson)){ throw "Sonuç JSON yok: $ResultJson" }
# Basit anahtar kelime skoru: csv: keyword,min_count
$rows = Import-Csv -LiteralPath $CsvPath
$txt  = (Get-Content -LiteralPath $ResultJson -Raw)
$total= 0; $hit=0
foreach($r in $rows){
  if(-not $r.keyword -or -not $r.min_count){ continue }
  $total++
  $count = ([regex]::Matches($txt, [regex]::Escape($r.keyword), 'IgnoreCase')).Count
  if($count -ge [int]$r.min_count){ $hit++ }
}
if($total -le 0){ Write-Host "[validator] kural yok (todolist.csv boş?)"; return }
$score = [math]::Round($hit / $total, 3)
Write-Host "[validator] score=$score (hit=$hit / total=$total)"
if($score -lt $MinScore){ throw "Score<$MinScore; aynı turda yeniden iste." }