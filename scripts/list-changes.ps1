param(
  [Parameter(Mandatory=$true)] [string]$Root,
  [Parameter(Mandatory=$true)] [string]$Start,
  [Parameter(Mandatory=$true)] [string]$End
)

# ---- Yardimci: bircok formati tolere eden tarih parse ----
function Parse-Dt([string]$Text) {
  $formats = @(
    'dd.MM.yyyy HH:mm','yyyy-MM-dd HH:mm','dd/MM/yyyy HH:mm',
    'dd.MM.yyyy HH:mm:ss','yyyy-MM-dd HH:mm:ss','dd/MM/yyyy HH:mm:ss'
  )
  foreach ($f in $formats) {
    try {
      return [datetime]::ParseExact($Text, $f, [Globalization.CultureInfo]::InvariantCulture)
    } catch {}
  }
  try { return [datetime]::Parse($Text, [Globalization.CultureInfo]::InvariantCulture) } catch {
    throw "Tarih/saat formati hatali: '$Text'. Ornek: '31.08.2025 10:00' veya '2025-08-31 10:00'"
  }
}

$startDt = Parse-Dt $Start
$endDt   = Parse-Dt $End

Write-Host "[INFO] KOK: $Root"
Write-Host "[INFO] TARiH: $($startDt.ToString('yyyy-MM-dd HH:mm')) -> $($endDt.ToString('yyyy-MM-dd HH:mm'))"

# ---- Filtreler ----
$excludeDirs = @('\.git\','\venv\','\__pycache__\','\node_modules\','\var\','.pytest_cache\','.mypy_cache\')
$includeExt  = @('.py','.html','.css','.js','.ts','.tsx','.json','.yml','.yaml','.toml','.ini',
                 '.cfg','.md','.sql','.ps1','.bat')

# ---- Dosyalari topla ----
$all = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue

# Dizin filtreleme
$filtered = $all | Where-Object {
  $p = $_.FullName
  -not ($excludeDirs | Where-Object { $p -match [regex]::Escape($_) })
}

# Zaman araligi
$changed = $filtered | Where-Object {
  ($_.LastWriteTime -ge $startDt) -and ($_.LastWriteTime -le $endDt)
}

# Sadece belirli uzantilar (binary karmasini engeller)
$changed = $changed | Where-Object { $includeExt -contains $_.Extension.ToLower() }

# ---- Cikti ----
"=== EN TAZE KODLAR / DEGİSEN-DOSYALAR ==="
"Root        : $Root"
"Interval    : $($startDt.ToString('yyyy-MM-dd HH:mm')) -> $($endDt.ToString('yyyy-MM-dd HH:mm'))"
"Generated   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
""
"{0,-20}  {1,10}  {2}" -f "LastWriteTime","Size(KB)","RelativePath"
"{0,-20}  {1,10}  {2}" -f "-------------------","---------","------------------------------"

$rootFixed = (Resolve-Path $Root).Path
$changed | Sort-Object LastWriteTime | ForEach-Object {
  $rel = $_.FullName.Substring($rootFixed.Length).TrimStart('\','/')
  $kb  = [Math]::Round(($_.Length/1KB),2)
  "{0,-20}  {1,10}  {2}" -f ($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')), $kb, $rel
}

# Toplam sayi
""
"Toplam dosya: {0}" -f ($changed | Measure-Object | Select-Object -ExpandProperty Count)
