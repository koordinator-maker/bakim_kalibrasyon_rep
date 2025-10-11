# REV: 1.0 | 2025-09-25 | Hash: TBD | Parça: 1/1
Param(
  [string]$OutDir = "targets/screens",
  [string]$AlsoCopyTo = ""
)
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (!(Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$path = Join-Path $OutDir ("screenshot-$ts.png")

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose()
$bmp.Dispose()

Write-Host "[SCREENSHOT] $path"

if ($AlsoCopyTo -and (Test-Path $AlsoCopyTo)) {
  Copy-Item $path -Destination (Join-Path $AlsoCopyTo ("screenshot-$ts.png")) -Force
}
