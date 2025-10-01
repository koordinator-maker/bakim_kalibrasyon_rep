param(
  [string]$Backlog  = "ops\backlog.json",
  [string]$TasksCsv = "tasks_template.csv",  # TEK CSV: dosya ad?m?z bu
  [switch]$Backup
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Backlog))  { throw "Backlog yok: $Backlog" }
if (-not (Test-Path $TasksCsv)) { throw "CSV yok: $TasksCsv" }

# backlog.json'u oku (d?z liste ya da {items:[...]} ikisini de destekle)
$root = Get-Content $Backlog -Raw | ConvertFrom-Json
$hasItemsProp = $false
$items = $root
if ($root -isnot [System.Collections.IEnumerable] -or $root -is [string]) {
  if ($root.PSObject.Properties.Name -contains 'items') {
    $items = $root.items; $hasItemsProp = $true
  } else {
    $items = @($root)
  }
}

# CSV'yi oku (tek kaynak)
$rows = Import-Csv -Path $TasksCsv

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

$changed = 0
foreach ($r in $rows) {
  $id = $r.id
  if (-not $id) { continue }

  # CSV?de bu s?tunlar yoksa sessizce ge?
  $hasDesign = $r.PSObject.Properties.Name -contains 'design_ref'
  $hasThresh = $r.PSObject.Properties.Name -contains 'visual_threshold'
  if (-not $hasDesign -and -not $hasThresh) { continue }

  $item = $items | Where-Object { $_.id -eq $id } | Select-Object -First 1
  if (-not $item) { Write-Warning "Backlog'da bulunamad?: $id"; continue }

  # design_ref (doluyken A?IK; bo?sa JSON'dan kald?r)
  $refPath = $null
  if ($hasDesign) {
    $refPath = $r.design_ref
    if ([string]::IsNullOrWhiteSpace($refPath)) { $refPath = $null }
  }
  if ($refPath) {
    $item | Add-Member -NotePropertyName design_ref -NotePropertyValue $refPath -Force
  } else {
    if ($item.PSObject.Properties.Name -contains 'design_ref') { $item.PSObject.Properties.Remove('design_ref') }
  }

  # visual_threshold (normalize; bo?sa JSON'dan kald?r)
  $thr = $null
  if ($hasThresh) { $thr = Normalize-Threshold $r.visual_threshold }
  if ($thr -ne $null) {
    $item | Add-Member -NotePropertyName visual_threshold -NotePropertyValue $thr -Force
  } else {
    if ($item.PSObject.Properties.Name -contains 'visual_threshold') { $item.PSObject.Properties.Remove('visual_threshold') }
  }

  Write-Host "[ok] $id -> design_ref='$refPath', visual_threshold=$thr" -ForegroundColor Green
  $changed++
}

if ($changed -gt 0) {
  if ($Backup) { Copy-Item $Backlog "$Backlog.bak" -Force }
  if ($hasItemsProp) { $root.items = $items }
  ($root | ConvertTo-Json -Depth 100) | Set-Content -Path $Backlog -Encoding UTF8
  Write-Host "[ok] backlog g?ncellendi: $Backlog ($changed item)" -ForegroundColor Green
} else {
  Write-Host "[info] CSV ile e?le?en de?i?iklik yok." -ForegroundColor Yellow
}
