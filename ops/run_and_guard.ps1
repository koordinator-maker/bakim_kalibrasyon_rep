param(
  [Parameter(Mandatory=$true)][string]$Steps,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$ExtraArgs = ""
)

$null = New-Item -ItemType Directory -Force -Path (Split-Path $Out) -ErrorAction SilentlyContinue
$logPath = [IO.Path]::ChangeExtension($Out,'log')

# Çalıştır ve stdout+stderr yakala
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "python"
$psi.Arguments = "tools\pw_flow.py --steps `"$Steps`" --out `"$Out`" $ExtraArgs"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($psi)
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()
"$stdout`n$stderr" | Out-File $logPath -Encoding utf8

# JSON geçerli mi?
$needFix = $true
if (Test-Path $Out) {
  try { $tmp = Get-Content $Out -Raw | ConvertFrom-Json -Depth 32; $needFix = $false } catch { $needFix = $true }
}

# Gerekirse fallback JSON yaz
if ($needFix) {
  $errSnip = ($stderr + " " + $stdout) -replace "\s+"," "
  if ($errSnip.Length -gt 1200) { $errSnip = $errSnip.Substring(0,1200) }
  $fallback = @{
    ok = $false
    results = @()
    tool_error = $errSnip
  } | ConvertTo-Json -Depth 8
  $fallback | Out-File $Out -Encoding utf8
}
Write-Host "[guard] wrote: $Out"
