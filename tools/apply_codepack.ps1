param(
  [Parameter(Mandatory=$true)]
  [string]$Pack
)
$ErrorActionPreference="Stop"

if (!(Test-Path $Pack)) { throw "Pack not found: $Pack" }
$content = Get-Content $Pack -Raw

$regex = [regex]'(?ms)^\s*###>\s*(?<path>.+?)\r?\n(?<body>.*?)(?:\r?\n)?###<'
$matches = $regex.Matches($content)
if ($matches.Count -eq 0) { throw "No blocks found. Use ###> <path> ... ###< delimiters." }

$root = Get-Location
$written = @()
foreach ($m in $matches) {
  $rel = $m.Groups['path'].Value.Trim()
  $body = $m.Groups['body'].Value
  $dest = Join-Path $root $rel
  $dir  = Split-Path $dest -Parent
  if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($dest, $body, [Text.UTF8Encoding]::new($false))
  $written += $rel
  Write-Host "[WRITE] $rel"
}
"[OK] Wrote $($written.Count) file(s)."