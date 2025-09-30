param(
  [Parameter(Mandatory=$true)][string]$A,
  [Parameter(Mandatory=$true)][string]$B
)
Add-Type -AssemblyName System.Drawing

function Get-ImageHash([string]$path) {
  if (!(Test-Path $path)) { throw "Image not found: $path" }
  $bmp = New-Object System.Drawing.Bitmap (Get-Item $path).FullName
  try {
    $thumb = New-Object System.Drawing.Bitmap 8,8
    $g = [System.Drawing.Graphics]::FromImage($thumb)
    $g.InterpolationMode = "HighQualityBicubic"
    $g.DrawImage($bmp, 0,0, 8,8)
    $g.Dispose()
    $vals = New-Object 'System.Collections.Generic.List[double]'
    for ($y=0;$y -lt 8;$y++) { for ($x=0;$x -lt 8;$x++) {
      $c = $thumb.GetPixel($x,$y)
      $vals.Add(0.299*$c.R + 0.587*$c.G + 0.114*$c.B)
    } }
    $avg = ($vals | Measure-Object -Average).Average
    $bits = New-Object 'System.Collections.Generic.List[int]'
    foreach ($v in $vals) { $bits.Add( [int]([double]$v - $avg -ge 0) ) }
    return ($bits -join '')
  } finally {
    $bmp.Dispose(); $thumb.Dispose()
  }
}

$h1 = Get-ImageHash $A
$h2 = Get-ImageHash $B
$dist = 0; for ($i=0;$i -lt 64;$i++) { if ($h1[$i] -ne $h2[$i]) { $dist++ } }
$sim = 1.0 - ($dist / 64.0)

$result = @{ a=$A; b=$B; similarity=[Math]::Round($sim,4) } | ConvertTo-Json -Compress
$result
if ($sim -ge 0.90) { exit 0 } else { exit 2 }
