# === load_env.ps1 - .env loader ===
$envFile = ".env"
if(!(Test-Path $envFile)){ throw ".env dosyasi yok!" }

foreach($line in (Get-Content $envFile)){
  if($line -match '^([^=#]+)=(.*)$'){
    $key = $matches[1].Trim()
    $val = $matches[2].Trim()
    [Environment]::SetEnvironmentVariable($key, $val, 'Process')
    Write-Host "[ENV] $key yuklendi" -ForegroundColor Gray
  }
}
Write-Host "[OK] .env yuklendi" -ForegroundColor Green
