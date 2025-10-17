<# automation_loop.ps1 — PS 5.1 compatible (OTO KODLAMA) #>
param(
  [string]$Repo=".",
  [string]$InboxDir="_otokodlama\in",
  [string]$OutDir="_otokodlama\out",
  [string]$ArchiveDir="_otokodlama\archive",
  [int]$MaxIters=50,
  [int]$WaitSeconds=5,
  [switch]$GitPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$Utf8NoBom=New-Object System.Text.UTF8Encoding($false)

function Write-Utf8([string]$Path,[string]$Content){
  $full=$Path; try{$full=(Resolve-Path -LiteralPath $Path -EA Stop).Path}catch{}
  $dir=[IO.Path]::GetDirectoryName($full); if($dir){New-Item -ItemType Directory -Force -Path $dir | Out-Null}
  [IO.File]::WriteAllText($full,$Content,$Utf8NoBom)
}
function Timestamp(){ (Get-Date).ToString('yyyyMMdd-HHmmss') }

# 0) ortam
Set-Location -LiteralPath $Repo
[Environment]::CurrentDirectory=(Get-Location).Path
New-Item -ItemType Directory -Force -Path $InboxDir,$OutDir,$ArchiveDir | Out-Null

# 1) yardımcılar
function Apply-Replacements($items){
  foreach($it in $items){
    $path=$it.path
    if($it.PSObject.Properties.Name -notcontains 'content_utf8' -and $it.PSObject.Properties.Name -notcontains 'content_b64'){
      throw "Replacement için content_utf8/content_b64 yok: $path"
    }
    $content=$null
    if($it.PSObject.Properties.Name -contains 'content_utf8'){ $content=[string]$it.content_utf8 }
    if(-not $content -and $it.PSObject.Properties.Name -contains 'content_b64'){
      $content=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$it.content_b64))
    }
    if(Test-Path $path){ Copy-Item -LiteralPath $path -Destination "$path.bak_$(Timestamp)" -Force } else {
      $dir=Split-Path -Parent $path; if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    }
    Write-Utf8 $path $content
  }
}

function Invoke-Commands($cmds,$logBase){
  $logs=@()
  $i=1
  foreach($c in $cmds){
    $log = ("{0}_{1}.log.txt" -f $logBase,("{0:00}" -f $i))
    $err = ("{0}_{1}.err.txt" -f $logBase,("{0:00}" -f $i))
    $i++
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName="cmd.exe"
    $psi.Arguments="/d /c $c"
    $psi.UseShellExecute=$false
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $p=[System.Diagnostics.Process]::Start($psi)
    $stdout=$p.StandardOutput.ReadToEnd()
    $stderr=$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    Write-Utf8 $log $stdout
    $errPath=$null
    if($stderr){ Write-Utf8 $err $stderr; $errPath=$err }
    $entry=@{ cmd=$c; exit=$p.ExitCode; out=$log; err=$errPath }
    $logs += $entry
  }
  ,$logs
}

function Collect-PlaywrightReport($destDir){
  $cand=Get-ChildItem -Recurse -File -Filter 'report.json' -EA SilentlyContinue |
    Where-Object { $_.FullName -match 'playwright-report[\\/].*data[\\/]report\.json$' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($cand){
    $dst=Join-Path $destDir 'playwright-report-data'
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item -LiteralPath $cand.FullName -Destination (Join-Path $dst 'report.json') -Force
    return (Join-Path $dst 'report.json')
  }
  $null
}

function Build-PassInventory($reportJson,$destDir){
  if(-not (Test-Path $reportJson)){ return $null }
  $j=Get-Content $reportJson -Raw | ConvertFrom-Json
  $pass=New-Object System.Collections.Generic.List[object]
  function Add-P([object]$n){
    if($null -eq $n){return}
    if($n.specs){
      foreach($s in $n.specs){
        $id=''; $file=$s.file; $title=$s.title; $line=$s.line
        if($title -match '^(E\d{3}\b|EQP-\d+)'){ $id=$Matches[1] } elseif($file -match '(E\d{3}|EQP-\d+)'){ $id=$Matches[1] }
        if($s.tests){
          foreach($t in $s.tests){
            $ok=$false
            if($t.PSObject.Properties.Name -contains 'outcome'){ $ok=($t.outcome -eq 'expected' -or $t.outcome -eq 'flaky') }
            elseif($t.PSObject.Properties.Name -contains 'status'){ $ok=($t.status -eq 'passed') }
            elseif($s.PSObject.Properties.Name -contains 'ok'){ $ok=[bool]$s.ok }
            if($ok){
              $proj=$t.projectName; if(-not $proj -and $t.project){ $proj=$t.project.name }; if(-not $proj){ $proj='default' }
              $dur=0
              if($t.results){ foreach($r in $t.results){
                if($r.PSObject.Properties.Name -contains 'duration'){ $dur+=[int]$r.duration }
                elseif($r.PSObject.Properties.Name -contains 'durationMs'){ $dur+=[int]$r.durationMs }
              }} elseif($t.duration){ $dur=[int]$t.duration }
              $pass.Add([pscustomobject]@{ id=$id; title=$title; file=$file; line=$line; project=$proj; durationMs=$dur })
            }
          }
        }
      }
    }
    if($n.suites){ foreach($c in $n.suites){ Add-P $c } }
  }
  Add-P $j
  $ts=(Get-Date).ToString('yyyyMMdd-HHmmss')
  $txt=Join-Path $destDir "passed_tests_$ts.txt"
  $csv=Join-Path $destDir "passed_tests_$ts.csv"
  $json=Join-Path $destDir "passed_tests_$ts.json"
  $md=Join-Path $destDir "pass_inventory_$ts.md"
  $lines=@(); $i=1
  foreach($r in $pass){
    $sec = if($r.durationMs){ '{0:N1}s' -f ($r.durationMs/1000.0) } else { '-' }
    $idS = if($r.id){ "[$($r.id)] " } else { "" }
    $lines += ("{0:00}. {1}{2} - {3} - proj:{4} - süre:{5}" -f $i,$idS,$r.title,$r.file,$r.project,$sec); $i++
  }
  Write-Utf8 $txt ($lines -join "`r`n")
  $pass | Export-Csv -Path ([IO.Path]::GetFullPath($csv)) -NoTypeInformation -Encoding UTF8
  Write-Utf8 $json ($pass | ConvertTo-Json -Depth 5)
  $mdRows=@("# PASS Envanteri - $ts","","| # | ID | Başlık | Dosya | Proje | Süre |","|---:|:---:|---|---|:--:|--:|"); $k=1
  foreach($r in $pass){
    $id=if($r.id){$r.id}else{'-'}
    $sec=if($r.durationMs){ '{0:N1}s' -f ($r.durationMs/1000.0) } else { '-' }
    $mdRows += "| $k | $id | $(($r.title -replace '\|','\|')) | $($r.file) | $($r.project) | $sec |"; $k++
  }
  Write-Utf8 $md ($mdRows -join "`r`n")
  @{ txt=$txt; csv=$csv; json=$json; md=$md }
}

function Git-PushIfRequested([switch]$DoPush){
  if(-not $DoPush){ return $null }
  try{
    git add -A
    $msg="BOT: apply packet " + (Timestamp)
    git commit -m $msg
    git rev-parse --abbrev-ref --symbolic-full-name "HEAD@{u}" >$null 2>&1
    if($LASTEXITCODE -ne 0){
      $branch = git rev-parse --abbrev-ref HEAD
      git push -u origin $branch
    } else {
      git push
    }
    return $msg
  } catch { return "git: $_" }
}

# 2) döngü
$iter=0
while($iter -lt $MaxIters){
  $iter++
  $pkt=Get-ChildItem -Path $InboxDir -File -Include *.json,*.zip -EA SilentlyContinue | Sort-Object LastWriteTime | Select-Object -First 1
  if(-not $pkt){ Start-Sleep -Seconds $WaitSeconds; continue }

  $ts=Timestamp
  $work=Join-Path $OutDir ("run_" + $ts)
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  $meta=@{ started=$ts; packet=$pkt.Name; logs=@(); status="running" }

  try{
    if($pkt.Extension -ieq ".zip"){
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $unzip=Join-Path $work "unzip"; New-Item -ItemType Directory -Force -Path $unzip | Out-Null
      [IO.Compression.ZipFile]::ExtractToDirectory($pkt.FullName,$unzip)
      $jsonPath=Get-ChildItem -Path $unzip -Recurse -File -Filter directive.json | Select-Object -First 1 -ExpandProperty FullName
      if(-not $jsonPath){ throw "ZIP içinde directive.json yok." }
      $directive=Get-Content $jsonPath -Raw | ConvertFrom-Json
    } else {
      $directive=Get-Content $pkt.FullName -Raw | ConvertFrom-Json
    }

    if($directive.env){
      foreach($k in $directive.env.PSObject.Properties.Name){
        $v=[string]$directive.env.$k
        [Environment]::SetEnvironmentVariable($k,$v,"Process")
      }
    }

    if($directive.replace_files){ Apply-Replacements $directive.replace_files }

    if($directive.run){
      $logs=Invoke-Commands $directive.run (Join-Path $work "cmd")
      $meta.logs=$logs
    }

    $rep=Collect-PlaywrightReport $work
    if($rep){
      $inv=Build-PassInventory $rep $work
      $meta.pass_inventory=$inv
    }

    $meta.git=(Git-PushIfRequested $GitPush)
    $meta.status="ok"
  } catch {
    $meta.status="error"; $meta.error="$_"
  }

  Write-Utf8 (Join-Path $work "meta.json") (($meta | ConvertTo-Json -Depth 8))

  if($meta.status -eq 'ok'){ $suffix='.ok' } else { $suffix='.err' }
  $archName = ($pkt.BaseName + '_' + $ts + $suffix + $pkt.Extension)
  Move-Item -LiteralPath $pkt.FullName -Destination (Join-Path $ArchiveDir $archName) -Force
}