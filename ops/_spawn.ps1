param(
  [Parameter(Mandatory=$true)][string]$File,
  [string[]]$Args = @(),
  [int]$HardTimeoutSec = 300,
  [int]$HeartbeatSec   = 5
)

# Argümanları tek stringe dönüştür (içinde boşluk olanları tırnakla)
function Join-Args([string[]]$arr){
  $arr | ForEach-Object {
    if ($_ -match '\s' -and $_ -notmatch '^".*"$') { '"' + $_ + '"' } else { $_ }
  } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | ForEach-Object { $_ } -join ' '
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $File
$psi.Arguments              = (Join-Args $Args)
$psi.UseShellExecute        = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow         = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$lastBeat = 0

while(-not $p.HasExited){
  while(-not $p.StandardOutput.EndOfStream){
    $line = $p.StandardOutput.ReadLine()
    if($line){ Write-Host $line; [Console]::Out.Flush() }
  }
  while(-not $p.StandardError.EndOfStream){
    $eline = $p.StandardError.ReadLine()
    if($eline){ Write-Host $eline -ForegroundColor DarkYellow; [Console]::Out.Flush() }
  }

  Start-Sleep -Milliseconds 50  # hızlandırıldı (100 -> 50)

  if($sw.Elapsed.TotalSeconds -ge $HardTimeoutSec){
    Write-Host "[spawn] HARD TIMEOUT ($HardTimeoutSec s). Killing..." -ForegroundColor Red
    try { $p.Kill() } catch {}
    break
  }

  if([int]$sw.Elapsed.TotalSeconds -ge ($lastBeat + $HeartbeatSec)){
    Write-Host ("[spawn] heartbeat {0}s" -f [int]$sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
    [Console]::Out.Flush()
    $lastBeat = [int]$sw.Elapsed.TotalSeconds
  }
}
# kuyrukta kalan
if($p){
  try{
    $restOut = $p.StandardOutput.ReadToEnd()
    if($restOut){ Write-Host $restOut; [Console]::Out.Flush() }
  }catch{}
  try{
    $restErr = $p.StandardError.ReadToEnd()
    if($restErr){ Write-Host $restErr -ForegroundColor DarkYellow; [Console]::Out.Flush() }
  }catch{}
}

exit ($p.ExitCode)












