# PS 5.1, ASCII only, no 'exit' — Full Playwright run (report-only)
param(
  [string]$Repo = "C:\dev\bakim_kalibrasyon",
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [string]$AdminUser = "admin",
  [string]$AdminPass = "admin123!"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function New-U8Dir([string]$p){ if($p){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Say([string]$m){ Write-Host $m }

function Find-Exe([string[]]$Candidates){
  foreach($n in $Candidates){
    $g = Get-Command $n -ErrorAction SilentlyContinue
    if($g){ return $g.Source }
  }
  $probes = @(
    { Join-Path $env:APPDATA        ("npm\" + $_) },
    { Join-Path $env:LOCALAPPDATA   ("Programs\nodejs\" + $_) },
    { Join-Path $env:ProgramFiles   ("nodejs\" + $_) },
    { Join-Path $env:ProgramFiles   ("nodejs\node_modules\npm\bin\" + $_) }
  )
  foreach($n in $Candidates){
    foreach($p in $probes){
      $path = & $p $n
      if(Test-Path $path){ return $path }
    }
  }
  return $null
}

# 0) Workspace
Set-Location $Repo
New-U8Dir "_otokodlama\out"
New-U8Dir "_otokodlama\logs"
New-U8Dir "_otokodlama\reports"
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logOut = "_otokodlama\out\full_stdout_$ts.txt"
$logErr = "_otokodlama\out\full_stderr_$ts.txt"

# 1) Server smoke (bilgi amaçlı)
$serverOK = $false
try{
  $probe = Invoke-WebRequest -UseBasicParsing -Uri (($BaseUrl.TrimEnd('/')) + '/admin/') -TimeoutSec 5
  if($probe.StatusCode -ge 200 -and $probe.StatusCode -lt 500){ $serverOK = $true }
}catch{ $serverOK = $false }
Say ("Server OK: " + $serverOK)

# 2) ENV
$env:BASE_URL   = $BaseUrl
$env:ADMIN_USER = $AdminUser
$env:ADMIN_PASS = $AdminPass

# 3) Playwright komutunu hazırla (npx.cmd -> fallback playwright.cmd)
$runner = "cmd.exe"
$npx    = Find-Exe @("npx.cmd","npx.exe","npx")
$pwCmd  = Join-Path (Get-Location) "node_modules\.bin\playwright.cmd"

if($npx){
  $inner = '"' + $npx + '" playwright test --config="playwright.all.config.cjs" --headed'
} elseif (Test-Path $pwCmd) {
  $inner = '"' + $pwCmd + '" test --config="playwright.all.config.cjs" --headed'
} else {
  Say "ERROR: Neither npx nor node_modules\.bin\playwright.cmd found."
  Say "       Install Playwright in this repo:"
  Say "         npm i -D @playwright/test"
  Say "         npx playwright install"
  $global:LASTEXITCODE = 2
  return
}

# 4) Çalıştırma (cmd.exe /d /s /c) ve log redirect
$arguments = '/d /s /c ' + '"' + $inner + '"'
$p = New-Object System.Diagnostics.Process
$p.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
$p.StartInfo.FileName = $runner
$p.StartInfo.Arguments = $arguments
$p.StartInfo.WorkingDirectory = (Get-Location).Path
$p.StartInfo.UseShellExecute = $false
$p.StartInfo.RedirectStandardOutput = $true
$p.StartInfo.RedirectStandardError  = $true
[void]$p.Start()
$out = $p.StandardOutput.ReadToEnd()
$err = $p.StandardError.ReadToEnd()
$p.WaitForExit()

$out | Out-File -FilePath $logOut -Encoding UTF8
$err | Out-File -FilePath $logErr -Encoding UTF8
$rc = $p.ExitCode

# 5) Rapor bul ve paketle (rapor yoksa playwright-report klasörünü topla)
$report = Get-ChildItem -Recurse -File -Filter "report.json" -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -like "*\playwright-report*\data\report.json" } |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1

$bundleDir = Join-Path "_otokodlama\out" ("full_bundle_" + $ts)
New-U8Dir $bundleDir
Copy-Item $logOut (Join-Path $bundleDir "stdout.txt") -Force
Copy-Item $logErr (Join-Path $bundleDir "stderr.txt") -Force

if($report){
  Copy-Item $report.FullName (Join-Path $bundleDir "report.json") -Force
} else {
  $pr = Get-ChildItem -Directory -Filter "playwright-report" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($pr){ Copy-Item $pr.FullName (Join-Path $bundleDir "playwright-report") -Recurse -Force }
}

$zip = Join-Path "_otokodlama\out" ("full_bundle_" + $ts + ".zip")
if(Test-Path $zip){ Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $zip -Force

# 6) Özet (terminali kapatma)
"=== FULL RUN ==="
"Server OK     : $serverOK"
"ExitCode      : $rc (0=PASS)"
"Stdout        : $(Resolve-Path $logOut)"
"Stderr        : $(Resolve-Path $logErr)"
if($report){ "Report JSON   : $(Resolve-Path $report.FullName)" } else { "Report JSON   : (not found; packed folder if exists)" }
"Bundle        : $(Resolve-Path $zip)"

$global:LASTEXITCODE = $rc
return