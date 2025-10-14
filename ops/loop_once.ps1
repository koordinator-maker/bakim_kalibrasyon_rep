Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Paths & ENV ---
$RepoRoot = (Get-Location).Path
$CsvPath  = Join-Path $RepoRoot "todolist.csv"
$OutDir   = Join-Path $RepoRoot "_otokodlama\out"
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# BASE_URL (varsayılan localhost)
$BaseUrl = $env:BASE_URL
if ([string]::IsNullOrWhiteSpace($BaseUrl)) { $BaseUrl = "http://127.0.0.1:8010" }

# --- Helpers ---
function NowStamp { Get-Date -Format "yyyyMMdd-HHmmss" }

function Save-Utf8NoBom([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
  [IO.File]::WriteAllText($Path,$Text,$enc)
}

function First-TodoTask([string]$Path){
  if (-not (Test-Path $Path)) { return $null }
  $rows = Import-Csv -LiteralPath $Path
  foreach($r in $rows){
    $st = ("" + $r.status).ToLowerInvariant()
    if ($st -eq "todo" -or $st -eq "pending") { return $r }
  }
  return $null
}

function Grep-ForTask($task){
  $id = ("" + $task.id)
  $title = ("" + $task.title)
  if ($id -match '^UH\d+') { return "UNIV-HEADINGS" }
  if ($id -match '^UF\d+') { return "UNIV-FORMS" }
  if ($id -match '^UL\d+') { return "UNIV-LANDMARKS" }
  if ($id -match '^UR\d+') { return "UNIV-ROUTES" }
  if ($id -match '^US\d+') { return "UNIV-SMOKE" }
  if ($id -match '^E10\d') { return "E10" }
  if ($title -match 'HEADINGS')   { return "UNIV-HEADINGS" }
  if ($title -match 'LANDMARKS')  { return "UNIV-LANDMARKS" }
  if ($title -match 'ROUTES')     { return "UNIV-ROUTES" }
  if ($title -match 'FORMS')      { return "UNIV-FORMS" }
  return $null
}

function Ensure-NpxOnPath {
  # Oturum PATH'ine AppData\Roaming\npm ekle (npx bu klasörde olur)
  $npmBin = Join-Path $env:APPDATA 'npm'
  if (Test-Path $npmBin) {
    if (-not ($env:Path -split ';' | Where-Object { $_ -eq $npmBin })) {
      $env:Path = "$npmBin;$env:Path"
    }
  }
}

function Find-Launcher {
  Ensure-NpxOnPath
  # npx varsa onu kullan; yoksa local playwright.cmd
  $npxHit = (cmd.exe /c "where npx" 2>$null | Select-Object -First 1)
  if ($npxHit) { return @{ kind="npx"; path=$npxHit } }
  $local = Join-Path $RepoRoot "node_modules\.bin\playwright.cmd"
  if (Test-Path $local) { return @{ kind="bin"; path=$local } }
  throw "Playwright bulunamadı. Önce: npm install && npx playwright install chromium"
}

function Run-Playwright([string]$grep,[string]$label){
  $ts = NowStamp
  $stdoutPath = Join-Path $OutDir ("pw_" + $label + "_stdout_" + $ts + ".txt")
  $stderrPath = Join-Path $OutDir ("pw_" + $label + "_stderr_" + $ts + ".txt")

  $launcher = Find-Launcher
  if ($launcher.kind -eq "npx") {
    $cmd = 'npx playwright test --config="playwright.all.config.cjs" --headed'
  } else {
    $cmd = '"' + $launcher.path + '" test --config="playwright.all.config.cjs" --headed'
  }
  if ($grep) { $cmd += (' -g "' + $grep + '"') }

  Push-Location $RepoRoot
  try {
    $all  = & $env:ComSpec /c $cmd 2>&1
    $code = $LASTEXITCODE
  } finally {
    Pop-Location
  }

  $out = ($all | ForEach-Object { $_.ToString() }) -join "`r`n"
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($stdoutPath, $out, $enc)
  [IO.File]::WriteAllText($stderrPath, "", $enc)

  return @{ code=$code; stdout=$stdoutPath; stderr=$stderrPath }
}

# --- 1) Görev seç ---
$task = First-TodoTask $CsvPath
if ($null -eq $task) {
  Write-Host "No TODO/PENDING task found."
  return
}
Write-Host ("Selected Task: {0} - {1}" -f $task.id, $task.title)

# --- 2) AI request iskeleti (ileri slash kullanıyoruz) ---
$ts = NowStamp
$reqRel = "_otokodlama/out/ai_request_" + $task.id + "_" + $ts + ".json"
$reqAbs = Join-Path $RepoRoot $reqRel
$payload = [pscustomobject]@{
  id      = "" + $task.id
  title   = "" + $task.title
  status  = "" + $task.status
  baseUrl = $BaseUrl
  note    = "Read-only; fixes will come as AI patch. Put response under _otokodlama/inbox."
}
Save-Utf8NoBom $reqAbs ($payload | ConvertTo-Json -Depth 5)

# --- 3) Subset koşusu ---
$grep = Grep-ForTask $task
$subset = $null
if ($grep) {
  Write-Host ("Running subset with grep: {0}" -f $grep)
  $subset = Run-Playwright -grep $grep -label "subset"
  Write-Host ("Subset ExitCode: {0}" -f $subset.code)
}

# --- 4) Full koşu kararı ---
$runPlan = $env:RunPlan
$fullAfterPass = $true
if ($env:FullAfterPass -match '^(?i:false|0|no)$') { $fullAfterPass = $false }
if ([string]::IsNullOrWhiteSpace($runPlan)) { $runPlan = "auto" }  # auto | subset | full

$needFull = $false
if     ($runPlan -eq "full")   { $needFull = $true }
elseif ($runPlan -eq "subset") {
  if ($subset -eq $null) { $needFull = $true }
  elseif ($subset.code -eq 0 -and $fullAfterPass) { $needFull = $true }
} else {
  if ($subset -eq $null) { $needFull = $true }
  elseif ($subset.code -ne 0) { $needFull = $true }
  elseif ($fullAfterPass) { $needFull = $true }
}

$full = $null
if ($needFull) {
  Write-Host "Running FULL..."
  $full = Run-Playwright -grep $null -label "full"
  Write-Host ("Full ExitCode: {0}" -f $full.code)
}

# --- 5) Özet ---
$sum = [pscustomobject]@{
  task    = "" + $task.id
  subset  = if ($subset) { $subset.code } else { $null }
  full    = if ($full)   { $full.code }   else { $null }
  request = $reqRel
}
$sum | ConvertTo-Json -Depth 5 | Write-Host