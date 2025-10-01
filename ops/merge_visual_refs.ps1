param(
  [string]$Backlog = "ops\backlog.json",
  [string]$Csv     = "ops\visual_refs.csv",
  [switch]$Backup
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Backlog)) { throw "Backlog yok: $Backlog" }
if (-not (Test-Path $Csv))     { throw "CSV yok: $Csv" }

# JSON oku
$plan = Get-Content $Backlog -Raw | ConvertFrom-Json

# CSV oku
$rows = Import-Csv -Path $Csv

# Invariant threshold normalize (0..1; 90 veya 90% -> 0.90; virg?l/dot fark? tolere)
function Normalize-Threshold([string]$raw) {
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  $t = $raw.Trim()
  if ($t.EndsWith("%")) { $t = $t.Substring(0, $t.Length-1) }
  $t = $t -replace ",", "."
  $n = 0.0
  $style = [System.Globalization.NumberStyles]::Float
  $cult  = [System.Globalization.CultureInfo]::InvariantCulture
  if (-not [double]::TryParse($t, $style, $cult, [ref]$n)) { throw "Ge?ersiz visual_threshold: '$raw'" }
  if ($n -gt 1) { $n = $n / 100.0 }
  if ($n -lt 0 -or $n -gt 1) { throw "visual_threshold aral?k d??? (0..1): $n" }
  [Math]::Round($n, 2)
}

# Merge
$changed = 0
foreach ($r in $rows) {
  $id = $r.id
  if (-not $id) { Write-Warning "Sat?rda id yok, atland?."; continue }
  $item = $plan | Where-Object { $_.id -eq $id } | Select-Object -First 1
  if (-not $item) { Write-Warning "Backlog'da bulunamad?: $id"; continue }

  $thr = $null
  try { $thr = Normalize-Threshold $r.visual_threshold } catch { throw "id=$id -> $_" }

  $refPath = $r.design_ref
  if ($refPath -and -not (Test-Path $refPath)) {
    Write-Warning "design_ref bulunamad?: $refPath (id=$id). Yine de yaz?yorum."
  }

  $item | Add-Member -NotePropertyName design_ref -NotePropertyValue $refPath -Force
  if ($thr -ne $null) {
    $item | Add-Member -NotePropertyName visual_threshold -NotePropertyValue $thr -Force
  }

  $changed++
  Write-Host "[ok] $id -> design_ref='$refPath', visual_threshold=$thr" -ForegroundColor Green
}

if ($changed -gt 0) {
  if ($Backup) { Copy-Item $Backlog "$Backlog.bak" -Force }
  ($plan | ConvertTo-Json -Depth 100) | Set-Content -Path $Backlog -Encoding UTF8
  Write-Host "[ok] backlog g?ncellendi: $Backlog ($changed item)" -ForegroundColor Green
} else {
  Write-Host "[info] CSV ile e?le?en de?i?iklik yok." -ForegroundColor Yellow
}
