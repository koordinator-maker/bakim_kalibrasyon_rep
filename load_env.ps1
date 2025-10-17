$envFile = ".env"
foreach($line in (Get-Content $envFile)){
  if($line -match '^([^=#]+)=(.*)$'){
    [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
  }
}
