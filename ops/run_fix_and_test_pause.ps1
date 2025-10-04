param([string]$BaseUrl="http://127.0.0.1:8010", [switch]$Headed, [switch]$Debug)

Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'; trap { throw }
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# 1) Backend düzeltici betik
powershell -ExecutionPolicy Bypass -File scripts\fix_e102_addform.ps1 -BaseUrl $BaseUrl

# 2) Testi çalıştır (npm/npx PowerShell wrapper bug'ından kaçınmak için *.cmd kullan)
$env:BASE_URL = $BaseUrl
$env:ALLOW_EQUIPMENT_ADD = "1"
if ($Debug) { $env:PWDEBUG = "1" }

$cmd = "playwright test tests/tasks.spec.cjs --project=chromium"
if ($Headed) { $cmd += " --headed" }

# npx yerine npx.cmd çağır
& "$env:ProgramFiles\nodejs\npx.cmd" $cmd
$code = $LASTEXITCODE

Write-Host "`nExit code: $code"
Read-Host "Kapatmak için Enter'a bas"
exit $code