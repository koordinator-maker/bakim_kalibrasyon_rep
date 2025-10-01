param(
  [string]$FlowsDir = "ops\flows"
)
$ErrorActionPreference = "Stop"

$create = Join-Path $FlowsDir "equipment_ui_create.flow"
$e2e    = Join-Path $FlowsDir "equipment_ui_e2e.flow"

if (-not (Test-Path $create)) { throw "Flow yok: $create" }

# 1) create.flow i?eri?i
$c = Get-Content -LiteralPath $create -Raw

# 2) create i?inden code/name de?erlerini ?ek
$codeVal = $null
$nameVal = $null
foreach($p in @(
  '(?m)^\s*FILL\s+.*?(id_code|name=code)[^\r\n]*\s+"([^"]+)"\s*$',
  '(?m)^\s*FILL\s+.*?(id_code|name=code)[^\r\n]*\s+([^\r\n"]+)\s*$'
)){ $m=[regex]::Match($c,$p); if($m.Success){ $codeVal=$m.Groups[$m.Groups.Count-1].Value.Trim(); break } }

foreach($p in @(
  '(?m)^\s*FILL\s+.*?(id_name|name=name)[^\r\n]*\s+"([^"]+)"\s*$',
  '(?m)^\s*FILL\s+.*?(id_name|name=name)[^\r\n]*\s+([^\r\n"]+)\s*$'
)){ $m=[regex]::Match($c,$p); if($m.Success){ $nameVal=$m.Groups[$m.Groups.Count-1].Value.Trim(); break } }

# 3) create'?n SONUNA, ayn? sayfada do?rulama ad?mlar?n? ekle
$append = @()
$append += 'WAIT  SELECTOR #content-main'
$append += 'WAIT  SELECTOR .messagelist'
$append += 'WAIT  SELECTOR form'

if ($codeVal -and $codeVal -ne '') {
  $append += 'WAIT  SELECTOR input#id_code'
  $append += ('WAIT  SELECTOR input#id_code[value*="'+$codeVal.Replace('"','\"')+'"]')
}
if ($nameVal -and $nameVal -ne '') {
  $append += 'WAIT  SELECTOR input#id_name'
  $append += ('WAIT  SELECTOR input#id_name[value*="'+$nameVal.Replace('"','\"')+'"]')
}

# Yedek olarak sayfa ba?l???nda veya i?erikte isim/code ge?ti mi (opsiyonel, yorum sat?r? b?rak?ld?)
# $append += ('WAIT  SELECTOR :has-text("'+ ($nameVal ?? $codeVal ?? "Kaydedildi") +'")')

# 4) tek ak?? dosyas? yaz
$all = $c.TrimEnd() + "`r`n" + ($append -join "`r`n") + "`r`n"
Set-Content -LiteralPath $e2e -Value $all -Encoding ASCII
Write-Host ("[ok] wrote E2E flow: {0} (code='{1}', name='{2}')" -f $e2e,$codeVal,$nameVal) -ForegroundColor Green
