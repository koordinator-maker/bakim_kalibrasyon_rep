param(
  [string]$Repo = ".",
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8010,
  [string]$AdminUser = $(if ($env:ADMIN_USER) { $env:ADMIN_USER } else { "admin" }),
  [string]$AdminPass = $(if ($env:ADMIN_PASS) { $env:ADMIN_PASS } else { "admin123!" })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8([string]$Path, [string]$Content) {
  $full = $Path
  try { $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path } catch {}
  $dir = [IO.Path]::GetDirectoryName($full)
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($full, $Content, $Utf8NoBom)
}

# 0) Kök ve çalışma dizini
Set-Location -LiteralPath $Repo
[Environment]::CurrentDirectory = (Get-Location).Path

# 1) Python yolları
$PyExe = Join-Path (Get-Location) "venv\Scripts\python.exe"
if (!(Test-Path $PyExe)) { $PyExe = "python" }
$PipCmd = "$PyExe -m pip"

# 2) Django kurulumu (requirements varsa onu kullan)
if (Test-Path "requirements.txt") {
  cmd /c "$PipCmd install -r requirements.txt"
} else {
  cmd /c "$PipCmd install django"
}

# 3) migrate + admin kullanıcı garantisi (temp py dosyası ile)
$tempEnsure = Join-Path $env:TEMP ("ensure_admin_" + [guid]::NewGuid().ToString() + ".py")
$pyEnsure = @"
from django.contrib.auth import get_user_model
U = get_user_model()
u, created = U.objects.get_or_create(username=r"$AdminUser", defaults={"email":"admin@example.com"})
u.is_staff = True
u.is_superuser = True
u.set_password(r"$AdminPass")
u.save()
print("ADMIN_READY", u.username)
"@
Write-Utf8 $tempEnsure $pyEnsure

cmd /c "$PyExe manage.py migrate"
cmd /c "$PyExe manage.py shell -c `"exec(open(r'$tempEnsure','r').read())`""

# 4) Sunucuyu arka planda başlat ve hazır olana kadar bekle
$Base = "http://$BindHost`:$Port"
$AdminUrl = "$Base/admin/"
$ServerProc = Start-Process -FilePath $PyExe -ArgumentList @("manage.py","runserver","$BindHost`:$Port") -PassThru -WindowStyle Hidden
Write-Host ("DEV server PID = {0}" -f $ServerProc.Id)

$ready = $false
for ($i=0; $i -lt 90; $i++) {
  try {
    $resp = Invoke-WebRequest -Uri $AdminUrl -UseBasicParsing -TimeoutSec 3
    if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) { $ready = $true; break }
  } catch { Start-Sleep -Milliseconds 700 }
}
if (-not $ready) {
  Write-Host "Server not ready: $AdminUrl" -ForegroundColor Red
  try { if ($ServerProc -and -not $ServerProc.HasExited) { $ServerProc | Stop-Process -Force } } catch {}
  exit 1
}

# 5) ENV ve Playwright testleri
$env:BASE_URL   = $Base
$env:ADMIN_USER = $AdminUser
$env:ADMIN_PASS = $AdminPass

$Npx = "npx"
cmd /c "$Npx playwright test --config=playwright.all.config.cjs --headed"
$PlayRC = $LASTEXITCODE

# 6) PASS envanteri (HTML rapordan)
$ReportJson = Join-Path (Get-Location) 'playwright-report\data\report.json'
if (-not (Test-Path $ReportJson)) {
  $cand = Get-ChildItem -Recurse -File -Filter 'report.json' |
    Where-Object { $_.FullName -match 'playwright-report[\\/].*data[\\/]report\.json$' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($cand) { $ReportJson = $cand.FullName }
}

if (Test-Path $ReportJson) {
  $OutDir = "_otokodlama\reports"
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $j = Get-Content $ReportJson -Raw | ConvertFrom-Json

  $pass = New-Object System.Collections.Generic.List[object]
  function Add-Pass([object]$n) {
    if ($null -eq $n) { return }
    if ($n.specs) {
      foreach ($s in $n.specs) {
        $id=''; $file=$s.file; $title=$s.title; $line=$s.line
        if ($title -match '^(E\d{3}\b|EQP-\d+)') { $id=$Matches[1] }
        elseif ($file -match '(E\d{3}|EQP-\d+)') { $id=$Matches[1] }
        if ($s.tests) {
          foreach ($t in $s.tests) {
            $ok = $false
            if ($t.PSObject.Properties.Name -contains 'outcome') { $ok = ($t.outcome -eq 'expected' -or $t.outcome -eq 'flaky') }
            elseif ($t.PSObject.Properties.Name -contains 'status') { $ok = ($t.status -eq 'passed') }
            elseif ($s.PSObject.Properties.Name -contains 'ok') { $ok = [bool]$s.ok }
            if ($ok) {
              $proj = $t.projectName; if (-not $proj -and $t.project) { $proj = $t.project.name }; if (-not $proj) { $proj = 'default' }
              $dur = 0
              if ($t.results) {
                foreach ($r in $t.results) {
                  if ($r.PSObject.Properties.Name -contains 'duration')   { $dur += [int]$r.duration }
                  elseif ($r.PSObject.Properties.Name -contains 'durationMs') { $dur += [int]$r.durationMs }
                }
              } elseif ($t.duration) { $dur = [int]$t.duration }
              $pass.Add([pscustomobject]@{ id=$id; title=$title; file=$file; line=$line; project=$proj; durationMs=$dur })
            }
          }
        }
      }
    }
    if ($n.suites) { foreach ($c in $n.suites) { Add-Pass $c } }
  }
  Add-Pass $j

  $pass = $pass | Sort-Object @{e={ if($_.id -match '^E(\d{3})$'){[int]$Matches[1]} elseif($_.id -match '^EQP-(\d+)$'){10000+[int]$Matches[1]} else { 999999 } }}, file, title

  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $Txt  = Join-Path $OutDir "passed_tests_$ts.txt"
  $Csv  = Join-Path $OutDir "passed_tests_$ts.csv"
  $Json = Join-Path $OutDir "passed_tests_$ts.json"
  $Md   = Join-Path $OutDir "pass_inventory_$ts.md"

  $lines = @(); $i = 1
  foreach ($r in $pass) {
    $sec = if ($r.durationMs) { '{0:N1}s' -f ($r.durationMs/1000.0) } else { '-' }
    $idS = if ($r.id) { "[$($r.id)] " } else { "" }
    $lines += ("{0:00}. {1}{2} - {3} - proj:{4} - süre:{5}" -f $i, $idS, $r.title, $r.file, $r.project, $sec); $i++
  }
  Write-Utf8 $Txt  ($lines -join "`r`n")
  $pass | Export-Csv -Path ([IO.Path]::GetFullPath($Csv)) -NoTypeInformation -Encoding UTF8
  Write-Utf8 $Json ($pass | ConvertTo-Json -Depth 5)

  $mdRows = @("# PASS Envanteri - $ts","","| # | ID | Başlık | Dosya | Proje | Süre |","|---:|:---:|---|---|:--:|--:|")
  $k=1
  foreach ($r in $pass) {
    $id  = if ($r.id) { $r.id } else { '-' }
    $sec = if ($r.durationMs) { '{0:N1}s' -f ($r.durationMs/1000.0) } else { '-' }
    $mdRows += "| $k | $id | $(($r.title -replace '\|','\|')) | $($r.file) | $($r.project) | $sec |"; $k++
  }
  Write-Utf8 $Md ($mdRows -join "`r`n")

  Write-Host "`n=== ÖZET ==="
  Write-Host ("Playwright exit code : {0}" -f $PlayRC)
  Write-Host ("PASS dosyaları      : {0}, {1}, {2}, {3}" -f $Txt, $Csv, $Json, $Md)
  Write-Host ("Rapordan okundu     : {0}" -f $ReportJson)
} else {
  Write-Host "HTML raporu (report.json) bulunamadı." -ForegroundColor Yellow
}

# 7) Sunucuyu kapat
try {
  if ($ServerProc -and -not $ServerProc.HasExited) { $ServerProc | Stop-Process -Force }
  $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "manage\.py.*runserver.*$BindHost`:$Port" }
  foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
} catch { }

if ($PlayRC -ne 0) { exit $PlayRC } else { exit 0 }