param(
  [Parameter(Mandatory=$true)][string]$DirectivePath,
  [string]$OutDir="_otokodlama\out",
  [string]$ArchiveDir="_otokodlama\archive"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$Utf8NoBom=New-Object System.Text.UTF8Encoding($false)
function WUtf8([string]$p,[string]$c){ $f=$p; try{$f=(Resolve-Path -LiteralPath $p -EA Stop).Path}catch{}; $d=[IO.Path]::GetDirectoryName($f); if($d){New-Item -ItemType Directory -Force -Path $d|Out-Null}; [IO.File]::WriteAllText($f,$c,$Utf8NoBom) }
function TS(){ (Get-Date).ToString('yyyyMMdd-HHmmss') }

if(-not (Test-Path $DirectivePath)){ throw "Bulunamadı: $DirectivePath" }
New-Item -ItemType Directory -Force -Path $OutDir,$ArchiveDir | Out-Null

$directive = Get-Content $DirectivePath -Raw | ConvertFrom-Json
# Alanlar opsiyonel ise boş kabul et
if ($directive.PSObject.Properties.Name -notcontains 'env')           { $directive | Add-Member -NotePropertyName env           -NotePropertyValue (@{}) }
if ($directive.PSObject.Properties.Name -notcontains 'replace_files') { $directive | Add-Member -NotePropertyName replace_files -NotePropertyValue (@()) }
if ($directive.PSObject.Properties.Name -notcontains 'run')           { $directive | Add-Member -NotePropertyName run           -NotePropertyValue (@()) }

Write-Host "[1/4] ENV"
foreach($k in $directive.env.PSObject.Properties.Name){
  $v=[string]$directive.env.$k
  [Environment]::SetEnvironmentVariable($k,$v,"Process")
  Write-Host "  $k=$v"
}

Write-Host "[2/4] Dosyalar"
foreach($it in $directive.replace_files){
  $path=$it.path
  $content=$null
  if($it.PSObject.Properties.Name -contains 'content_utf8'){ $content=[string]$it.content_utf8 }
  elseif($it.PSObject.Properties.Name -contains 'content_b64'){ $content=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$it.content_b64)) }
  else{ throw "content_utf8/content_b64 yok: $path" }
  if(Test-Path $path){ Copy-Item -LiteralPath $path -Destination "$path.bak_$(TS)" -Force } else {
    $d=Split-Path -Parent $path; if($d){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
  }
  WUtf8 $path $content
  Write-Host "  wrote: $path"
}

Write-Host "[3/4] Komutlar"
$i=1; $runLogs=@()
foreach($c in $directive.run){
  $base=Join-Path $OutDir ("cmd_" + ("{0:00}" -f $i)); $i++
  $log=$base+".log.txt"; $err=$base+".err.txt"
  $psi=New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName="cmd.exe"; $psi.Arguments="/d /c $c"
  $psi.UseShellExecute=$false; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
  $p=[System.Diagnostics.Process]::Start($psi)
  $stdout=$p.StandardOutput.ReadToEnd(); $stderr=$p.StandardError.ReadToEnd()
  $p.WaitForExit()
  WUtf8 $log $stdout; if($stderr){ WUtf8 $err $stderr }
  $obj=@{cmd=$c; exit=$p.ExitCode; out=$log}; if($stderr){ $obj.err=$err }; $runLogs+=$obj
  Write-Host ("  > {0} (exit={1})" -f $c,$p.ExitCode)
}

Write-Host "[4/4] Playwright raporu"
$cand=Get-ChildItem -Recurse -File -Filter 'report.json' -EA SilentlyContinue |
  Where-Object { $_.FullName -match 'playwright-report[\\/].*data[\\/]report\.json$' } |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($cand){
  $repDir=Join-Path $OutDir ("report_" + (TS)); New-Item -ItemType Directory -Force -Path $repDir | Out-Null
  Copy-Item -LiteralPath $cand.FullName -Destination (Join-Path $repDir "report.json") -Force
  Write-Host ("  report.json -> {0}" -f $repDir)
}else{
  Write-Host "  report.json bulunamadı (atlandı)."
}

# Arşivle
$dst = Join-Path $ArchiveDir ( (Split-Path -Leaf $DirectivePath) + "_" + (TS) + ".ok" )
Move-Item -LiteralPath $DirectivePath -Destination $dst -Force