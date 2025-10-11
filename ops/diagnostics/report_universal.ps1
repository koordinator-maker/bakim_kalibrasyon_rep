param(
  [string]$Repo = ".",
  [string]$OutDir = "_otokodlama\reports",
  [string]$BaseUrl = "http://127.0.0.1:8010",
  [string]$EntryPath = "/admin/"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = Resolve-Path $Repo
Set-Location $repo
$ts   = (Get-Date).ToString("yyyyMMdd-HHmmss")
$dir  = Join-Path $repo $OutDir
$null = New-Item -ItemType Directory -Force -Path $dir
$out  = Join-Path $dir "universal_findings_$ts.txt"

function UX-W([string]$s){ Add-Content -Path $out -Value $s }
function UX-H([string]$t){ UX-W ""; UX-W "=== $t ===" }
function UX-KV($k,$v){ UX-W ("* $($k): $($v)") }
function UX-Result($name,$status,$note=""){
  $icon = if($status -eq "PASS"){"[PASS]"} elseif($status -eq "WARN"){"[WARN]"} else {"[FAIL]"}
  if([string]::IsNullOrWhiteSpace($note)){ UX-W("$icon $name") } else { UX-W("$icon $name — $note") }
}
function UX-GetHtml([string]$url){
  try{
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30 -Method GET
    return [pscustomobject]@{ Status=$r.StatusCode; Html=$r.Content }
  } catch {
    try{
      $r = Invoke-WebRequest -Uri $url -TimeoutSec 30 -Method GET
      return [pscustomobject]@{ Status=$r.StatusCode; Html=$r.Content }
    } catch {
      $hc = New-Object System.Net.Http.HttpClient
      $t  = $hc.GetAsync($url).Result
      $h  = $t.Content.ReadAsStringAsync().Result
      return [pscustomobject]@{ Status=[int]$t.StatusCode; Html=$h }
    }
  }
}

UX-H "UNIVERSAL Hata Arama (yalnız TESPİT/BİLDİRİM)"
UX-KV "Zaman" (Get-Date)
UX-KV "Repo"  $repo
UX-KV "BaseUrl" $BaseUrl
UX-KV "EntryPath" $EntryPath

# 1) Araç mevcudiyeti
UX-H "Araç Mevcudiyeti"
foreach($c in @("node","npm","python","npx")){
  $exists = (Get-Command $c -ErrorAction SilentlyContinue) -ne $null
  UX-Result $c ($(if($exists){"PASS"}else{"WARN"})) ($(if($exists){"bulundu"}else{"yok"}))
}

# 2) UNIV-FORMS — 'page.response(' imzası
UX-H "UNIV-FORMS — imza taraması"
$testsDir = Join-Path $repo "tests"
if(Test-Path $testsDir){
  $hits = @()
  Get-ChildItem $testsDir -Recurse -File -Include *.spec.* | ForEach-Object {
    try{
      $raw = Get-Content $_.FullName -Raw -ErrorAction Stop
      $m = Select-String -InputObject $raw -Pattern "page\.response\s*\(" -AllMatches
      if($m){
        $line = (Select-String -Path $_.FullName -Pattern "page\.response\s*\(" | Select-Object -First 1)
        $hits += [pscustomobject]@{ File=$_.FullName; Line=$line.LineNumber; Preview=$line.Line.Trim() }
      }
    } catch {}
  }
  if($hits.Count -gt 0){
    UX-Result "page.response() imzası" "FAIL" "Aşağıda listelendi"
    foreach($h in $hits){ UX-W ("  - {0} (satır {1})  örnek: {2}" -f $h.File,$h.Line,$h.Preview) }
  } else {
    UX-Result "page.response() imzası" "PASS" "Bulunmadı"
  }
} else {
  UX-Result "tests dizini" "WARN" "tests/ yok"
}

# 3) Login sayfası H1/heading
UX-H "UNIV-SMOKE — H1/heading kontrolü"
try{
  $url = [Uri]::new((New-Object System.Uri ($BaseUrl.TrimEnd('/'))), $EntryPath.TrimStart('/'))
  $r = UX-GetHtml $url.AbsoluteUri
  UX-KV "HTTP Status" $r.Status
  $html = $r.Html
  $h1Count = ([regex]::Matches($html,"<h1\b[^>]*>",'IgnoreCase')).Count
  $roleHeading = ([regex]::Matches($html,"role\s*=\s*['""]heading['""]",'IgnoreCase')).Count
  UX-KV "H1 sayısı" $h1Count
  UX-KV "role='heading' sayısı" $roleHeading
  if($h1Count -eq 0 -and $roleHeading -eq 0){
    UX-Result "Başlık (H1/heading)" "FAIL" "Expected > 0, Received 0"
  } else {
    UX-Result "Başlık (H1/heading)" "PASS"
  }
} catch {
  UX-Result "UNIV-SMOKE kontrolü" "WARN" $_.Exception.Message
}

# 4) #content-start imi
UX-H "UNIV-ROUTES — #content-start imi"
try{
  if(-not $html){
    $url2 = [Uri]::new((New-Object System.Uri ($BaseUrl.TrimEnd('/'))), $EntryPath.TrimStart('/'))
    $html = (UX-GetHtml $url2.AbsoluteUri).Html
  }
  $hasAnchor = $html -match "id\s*=\s*['""]content-start['""]" -or $html -match "name\s*=\s*['""]content-start['""]"
  UX-KV "#content-start imi" ($(if($hasAnchor){"VAR"}else{"YOK"}))
  if(-not $hasAnchor){ UX-Result "Heading/#content-start" "WARN" "imi bulunamadı" }
  else { UX-Result "Heading/#content-start" "PASS" }
} catch {
  UX-Result "UNIV-ROUTES gözlemi" "WARN" $_.Exception.Message
}

# 5) Playwright rapor dizini
UX-H "Playwright Rapor Dizini"
$pw = Join-Path $repo "playwright-report"
if(Test-Path $pw){
  $idx = Test-Path (Join-Path $pw "index.html")
  UX-Result "playwright-report" "PASS" ("index.html " + ($(if($idx){"VAR"}else{"YOK"})))
} else {
  UX-Result "playwright-report" "WARN" "Rapor dizini yok"
}

UX-H "SON"
UX-W "Bu dosya yalnızca TESPİT/BİLDİRİM amaçlıdır. Yeni test eklenmemiştir."
Write-Host "Rapor: $out"
