param(
  [string]$RepoRoot=".",
  [string]$OutDir="_deliverables",
  [string[]]$IncludeDirs=@("tests"),
  [string[]]$IncludeFiles=@(
    "tests\*.spec.*","tests\*.test.*","tests\helpers*.js",
    "playwright.config.*","playwright.*.config.*",
    "package.json","package-lock.json"
  ),
  [int]$MaxCharsPerLine=100,
  [int]$FontSizePt=10,
  [int]$LeadingPt=12,
  [int]$MarginL=48,
  [int]$MarginR=48,
  [int]$MarginT=54,
  [int]$MarginB=54,
  [switch]$AlsoZip
)

$ErrorActionPreference='Stop'

function Resolve-Repo([string]$rr){
  if($rr -and (Test-Path $rr)){ return (Resolve-Path $rr).Path }
  try{ $r = (& git rev-parse --show-toplevel) }catch{ $r = $null }
  if(-not $r){ $r = (Resolve-Path ".").Path }
  return (Resolve-Path $r).Path
}
function New-Dir([string]$p){
  $full = [IO.Path]::GetFullPath($p)
  if(-not (Test-Path $full)){ New-Item -ItemType Directory -Force -Path $full | Out-Null }
  return $full
}

$A4W=595; $A4H=842
function Pdf-Escape([string]$s){
  if($null -eq $s){ return "" }
  $s = $s -replace '\\','\\' -replace '\(','\(' -replace '\)','\)'
  return $s
}
function To-AsciiSafe([string]$s){
  if($null -eq $s){ return "" }
  $map=@{'ç'='c';'Ç'='C';'ğ'='g';'Ğ'='G';'ı'='i';'İ'='I';'ö'='o';'Ö'='O';'ş'='s';'Ş'='S';'ü'='u';'Ü'='U'}
  $sb=New-Object System.Text.StringBuilder
  foreach($ch in $s.ToCharArray()){
    $c=[string]$ch
    if($map.ContainsKey($c)){[void]$sb.Append($map[$c])}
    elseif([int][char]$ch -lt 32){[void]$sb.Append(' ')}
    elseif([int][char]$ch -gt 126){[void]$sb.Append('?')}
    else{[void]$sb.Append($c)}
  }
  return $sb.ToString()
}
function Wrap-Lines([string]$text,[int]$max){
  $t = ($text -replace "`r`n","`n") -replace "`r","`n"
  $t = $t -replace "`t","  "
  $out = New-Object System.Collections.Generic.List[string]
  foreach($ln in $t.Split("`n")){
    $line=$ln
    if([string]::IsNullOrEmpty($line)){ $out.Add(""); continue }
    if($line.Length -le $max){ $out.Add($line); continue }
    $start=0
    while($start -lt $line.Length){
      $len=[Math]::Min($max,$line.Length-$start)
      $chunk=$line.Substring($start,$len)
      if(($start+$len) -lt $line.Length){
        $sp=$chunk.LastIndexOf(' ')
        if($sp -ge [int]($len*0.6)){ $chunk=$chunk.Substring(0,$sp); $len=$sp }
      }
      $out.Add($chunk)
      $start+=$len
    }
  }
  return ,$out
}

class PdfBuilder {
  [System.IO.MemoryStream]$ms
  [System.Text.Encoding]$enc
  [System.Collections.Generic.List[int]]$ofs
  [System.Collections.Generic.List[string]]$objs
  [int]$objCount
  PdfBuilder(){
    $this.ms=New-Object System.IO.MemoryStream
    $this.enc=New-Object System.Text.ASCIIEncoding
    $this.ofs=New-Object System.Collections.Generic.List[int]
    $this.objs=New-Object System.Collections.Generic.List[string]
    $this.objCount=0
  }
  [int] AddObj([string]$body){
    $this.objCount++
    $this.objs.Add($body)
    return $this.objCount
  }
  [void] Write([string]$s){
    $bytes=$this.enc.GetBytes($s)
    $this.ms.Write($bytes,0,$bytes.Length) | Out-Null
  }
  [byte[]] Build(){
    $this.Write("%PDF-1.4`n%âãÏÓ`n")
    $this.ofs.Clear()
    for($i=0;$i -lt $this.objs.Count;$i++){
      $this.ofs.Add([int]$this.ms.Position)
      $n=$i+1
      $this.Write("$n 0 obj`n")
      $this.Write($this.objs[$i])
      if(-not $this.objs[$i].EndsWith("`n")){ $this.Write("`n") }
      $this.Write("endobj`n")
    }
    $xref=[int]$this.ms.Position
    $this.Write("xref`n")
    $this.Write(("0 {0}`n" -f ($this.objCount+1)))
    $this.Write("0000000000 65535 f `n")
    foreach($o in $this.ofs){ $this.Write(("{0:0000000000} 00000 n `n" -f $o)) }
    $this.Write("trailer`n")
    $this.Write(("<< /Size {0} /Root 1 0 R >>`n" -f ($this.objCount+1)))
    $this.Write("startxref`n")
    $this.Write("$xref`n%%EOF")
    return $this.ms.ToArray()
  }
}

$repo = Resolve-Repo $RepoRoot
Set-Location $repo
$outDirAbs = New-Dir (Join-Path $repo $OutDir)
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$pdfPath = Join-Path $outDirAbs ("tests_code_dump_{0}.pdf" -f $ts)
$zipPath = Join-Path $outDirAbs ("tests_code_dump_{0}.zip" -f $ts)

$files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'

foreach($d in $IncludeDirs){
  $p = Join-Path $repo $d
  if(Test-Path $p){
    $g = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue
    if($g){ [void]$files.AddRange($g) }
  }
}
foreach($pat in $IncludeFiles){
  $g = Get-ChildItem -Path (Join-Path $repo '*') -Recurse -File -Include $pat -ErrorAction SilentlyContinue
  if($g){ [void]$files.AddRange($g) }
}

$uniq = $files | Sort-Object FullName -Unique |
  Sort-Object @{e={ if($_.Name -match 'helpers|config'){0}else{1} }}, FullName

if(-not $uniq -or $uniq.Count -eq 0){
  Write-Host "[warn] Test ile ilişkili dosya bulunamadı."; exit 0
}

$usableW = $A4W - $MarginL - $MarginR
$usableH = $A4H - $MarginT - $MarginB
$linesPerPage = [Math]::Max(5,[Math]::Floor($usableH / $LeadingPt))

$allLines = New-Object System.Collections.Generic.List[string]
$allLines.Add(("TEST CODE DUMP — {0}" -f (Get-Date)))
$allLines.Add(("Repo : {0}" -f $repo))
$allLines.Add(("Toplam dosya: {0}" -f $uniq.Count))
$allLines.Add(("".PadRight([Math]::Min($MaxCharsPerLine,80),'-')))

foreach($fi in $uniq){
  $rel = $fi.FullName.Substring($repo.Length).TrimStart('\','/')
  $allLines.Add(("=== {0} ===" -f $rel))
  try{ $raw = Get-Content $fi.FullName -Raw -Encoding UTF8 }catch{ $raw = Get-Content $fi.FullName -Raw }
  $wrapped = Wrap-Lines $raw $MaxCharsPerLine
  foreach($w in $wrapped){ $allLines.Add($w) }
  $allLines.Add("")
}

$pagesText=@()
for($i=0;$i -lt $allLines.Count;$i+=$linesPerPage){
  $pagesText += ,($allLines[$i..([Math]::Min($i+$linesPerPage-1,$allLines.Count-1))])
}

function Build-PageStream([string[]]$lines){
  $sb=New-Object System.Text.StringBuilder
  $top = [int]($A4H - $MarginT)
  [void]$sb.Append("BT`n/F1 $FontSizePt Tf`n$([int]$MarginL) $top Td`n$LeadingPt TL`n")
  foreach($ln in $lines){
    $s = Pdf-Escape (To-AsciiSafe $ln)
    [void]$sb.Append("("+$s+") Tj`nT*`n")
  }
  [void]$sb.Append("ET`n")
  $bytes=[System.Text.Encoding]::ASCII.GetBytes($sb.ToString())
  return ("<< /Length {0} >>`nstream`n{1}endstream`n" -f $bytes.Length,([System.Text.Encoding]::ASCII.GetString($bytes)))
}

$pdf = [PdfBuilder]::new()
$fontObj = "<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>"

$contentIdx=@(); $pageObjIdx=@()
foreach($ptxt in $pagesText){
  $ci = $pdf.AddObj( (Build-PageStream $ptxt) )
  $pi = $pdf.AddObj(@"
<< /Type /Page
   /Parent 2 0 R
   /MediaBox [0 0 $A4W $A4H]
   /Resources << /Font << /F1 3 0 R >> >>
   /Contents $ci 0 R
>>
"@)
  $contentIdx += $ci; $pageObjIdx += $pi
}
$kids = ($pageObjIdx | ForEach-Object { "{0} 0 R" -f $_ }) -join ' '
$pagesBody = "<< /Type /Pages /Kids [ $kids ] /Count {0} >>" -f $pageObjIdx.Count

$idxCatalog = $pdf.AddObj("<< /Type /Catalog /Pages 2 0 R >>")
$idxPages   = $pdf.AddObj($pagesBody)
$idxFont    = $pdf.AddObj($fontObj)

$bytes = $pdf.Build()
[IO.File]::WriteAllBytes($pdfPath,$bytes)
Write-Host "[ok] PDF hazır: $pdfPath"

if($AlsoZip){
  if(Test-Path $zipPath){ Remove-Item $zipPath -Force }
  Compress-Archive -Path ($uniq | ForEach-Object FullName) -DestinationPath $zipPath -CompressionLevel Optimal
  Write-Host "[ok] ZIP hazır: $zipPath"
}