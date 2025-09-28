param(
  [string]$Base       = "http://127.0.0.1:8010",
  [string]$Start      = "/admin/",
  [string]$Out        = "_otokodlama\smoke\links.json",
  [int]   $Depth      = 1,
  [int]   $Limit      = 200,
  [string]$PathPrefix = "",
  [string]$LoginPath  = "/admin/login/",
  [string]$User       = "admin",
  [string]$Pass       = "Admin!2345",
  [int]   $Timeout    = 20000
)

$null = New-Item -ItemType Directory -Force -Path (Split-Path $Out) -ErrorAction SilentlyContinue

$argsList = @(
  "tools\link_smoke.py",
  "--base", $Base,
  "--start", $Start,
  "--out", $Out,
  "--depth", $Depth,
  "--limit", $Limit,
  "--timeout", $Timeout
)
if ($PathPrefix) { $argsList += @("--path-prefix", $PathPrefix) }
if ($LoginPath)  { $argsList += @("--login-path",  $LoginPath)  }
if ($User)       { $argsList += @("--username",    $User)       }
if ($Pass)       { $argsList += @("--password",    $Pass)       }

python $argsList
$exit = $LASTEXITCODE
if ($exit -ne 0) {
  Write-Host "[link-smoke] KIRMIZI (exit=$exit)" -ForegroundColor Red
} else {
  Write-Host "[link-smoke] YEŞİL" -ForegroundColor Green
}
exit $exit
