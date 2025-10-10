# Rev: 2025-09-28 15:20 r4
param(
  [Parameter(Mandatory=$true)][string]$Base,
  [Parameter(Mandatory=$true)][string]$Start,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$Depth = 1,
  [int]$Limit = 150,
  [string]$PathPrefix = "/",
  [string]$LoginPath = "/admin/login/",
  [string]$User = "admin",
  [string]$Pass = "Admin!2345",
  [int]$Timeout = 20000,
  [string]$OkRedirectTo = ""   # ör: "/_direct/.*|/admin/.*"
)

function Join-Url([uri]$baseUri, [string]$url) {
  if ([string]::IsNullOrWhiteSpace($url)) { return $null }
  $u = $null
  if ([System.Uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$u)) { return $u }
  return [uri]::new($baseUri, $url)
}

function InScope([string]$locPath, [string]$prefix) {
  if ([string]::IsNullOrWhiteSpace($locPath)) { return $false }
  if ([string]::IsNullOrWhiteSpace($prefix))  { return $true }
  return $locPath.ToLower().StartsWith($prefix.ToLower())
}

function DepthOf([string]$path, [string]$prefix) {
  if (-not $path) { return 0 }
  $p   = $path
  $pre = if ($null -ne $prefix) { $prefix } else { "" }
  $p   = $p.Trim('/')
  $pre = $pre.Trim('/')
  if ($pre -and $p.ToLower().StartsWith($pre.ToLower())) {
    $p = $p.Substring($pre.Length).Trim('/')
  }
  if ([string]::IsNullOrWhiteSpace($p)) { return 0 }
  return ($p.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries).Length)
}

function ParseLinks([string]$html, [uri]$docUri) {
  $set = New-Object System.Collections.Generic.HashSet[string]
  if (-not $html) { return @() }
  $rx = [regex]'(?isx)
      <a\b[^>]*?href\s*=\s*["''](?<u>[^"''#>]+)["'']
    | <link\b[^>]*?href\s*=\s*["''](?<u>[^"''#>]+)["'']
    | <script\b[^>]*?src\s*=\s*["''](?<u>[^"''#>]+)["'']
  '
  foreach ($m in $rx.Matches($html)) {
    $u = $m.Groups['u'].Value
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    try {
      $abs = (Join-Url $docUri $u)
      if ($abs) { [void]$set.Add($abs.AbsolutePath) }
    } catch {}
  }
  # .ToArray() .NET Framework'te extension; 5.1'de garanti değil → düz diziye çevir
  return @($set)
}

Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$cookieJar = New-Object System.Net.CookieContainer
$handler.CookieContainer   = $cookieJar
$handler.AllowAutoRedirect = $false
$client  = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromMilliseconds([Math]::Max(1000, $Timeout))
$baseUri = [uri]$Base

function Get-Resp([uri]$uri, [string]$method="GET", [string]$body="", [hashtable]$headers=@{}) {
  $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::$method, $uri)
  foreach ($k in $headers.Keys) { $req.Headers.TryAddWithoutValidation($k, [string]$headers[$k]) | Out-Null }
  if ($method -eq "POST") {
    $req.Content = New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, "application/x-www-form-urlencoded")
  }
  $resp = $client.SendAsync($req).Result
  return $resp
}

function Do-Login {
  try {
    $loginUri = Join-Url $baseUri $LoginPath
    $r1 = Get-Resp $loginUri "GET"
    $html = $r1.Content.ReadAsStringAsync().Result
    $token = ""
    $m = [regex]::Match($html, 'name=["'']csrfmiddlewaretoken["'']\s+value=["'']([^"'']+)["'']', 'IgnoreCase')
    if ($m.Success) { $token = $m.Groups[1].Value }
    $body = "username=$([uri]::EscapeDataString($User))&password=$([uri]::EscapeDataString($Pass))"
    if ($token) { $body += "&csrfmiddlewaretoken=$([uri]::EscapeDataString($token))" }
    $null = Get-Resp $loginUri "POST" $body @{ "Referer" = $loginUri.AbsoluteUri }
    return $true
  } catch {
    Write-Host "[link-smoke] login hata: $($_.Exception.Message)" -ForegroundColor Yellow
    return $false
  }
}

$null = Do-Login

$queue   = New-Object System.Collections.Generic.Queue[object]
$visited = New-Object System.Collections.Generic.HashSet[string]
$bad     = New-Object System.Collections.Generic.List[object]
$checked = 0

$startUri = Join-Url $baseUri $Start
$queue.Enqueue([pscustomobject]@{ Uri=$startUri; Depth=0 })

while(($queue.Count -gt 0) -and ($checked -lt $Limit)) {
  $item = $queue.Dequeue()
  $u = $item.Uri
  $d = [int]$item.Depth
  if (-not $u) { continue }

  $key = $u.AbsolutePath.ToLower()
  if ($visited.Contains($key)) { continue }
  [void]$visited.Add($key)

  try {
    $resp = Get-Resp $u "GET"
    $status = [int]$resp.StatusCode
    $locHdr = $resp.Headers.Location
    $locAbs = $null
    if ($locHdr) { $locAbs = Join-Url $u $locHdr.ToString() }

    if ($status -ge 300 -and $status -lt 400) {
      $okRedirect = $false
      if ($locAbs -and -not [string]::IsNullOrWhiteSpace($OkRedirectTo)) {
        if ($locAbs.AbsolutePath -match $OkRedirectTo) { $okRedirect = $true }
      }
      $inScopeNext = ($locAbs -ne $null) -and (InScope $locAbs.AbsolutePath $PathPrefix)
      if ($inScopeNext -and -not $okRedirect) {
        $locStr = if ($locAbs) { $locAbs.AbsoluteUri } else { "" }
        $bad.Add([pscustomobject]@{ url=$u.AbsoluteUri; status=$status; location=$locStr }) | Out-Null
      }
      if ($locAbs -and (InScope $locAbs.AbsolutePath $PathPrefix) -and ($d -lt $Depth)) {
        $queue.Enqueue([pscustomobject]@{ Uri=$locAbs; Depth=$d })
      }
    }
    elseif ($status -ge 200 -and $status -lt 300) {
      $ct = $resp.Content.Headers.ContentType
      if ($ct -and $ct.MediaType -like "text/html") {
        $html = $resp.Content.ReadAsStringAsync().Result
        if ((InScope $u.AbsolutePath $PathPrefix) -and ($d -lt $Depth)) {
          foreach ($p in (ParseLinks $html $u)) {
            if (InScope $p $PathPrefix) {
              $depthNext = (DepthOf $p $PathPrefix)
              if ($depthNext -le $Depth) {
                $abs = Join-Url $baseUri $p
                if ($abs -and -not $visited.Contains($abs.AbsolutePath.ToLower())) {
                  $queue.Enqueue([pscustomobject]@{ Uri=$abs; Depth=$depthNext })
                }
              }
            }
          }
        }
      }
    }
    else {
      $bad.Add([pscustomobject]@{ url=$u.AbsoluteUri; status=$status; location="" }) | Out-Null
    }
  } catch {
    $msg = $_.Exception.Message
    Write-Host "[link-smoke] GET hata: $msg" -ForegroundColor Yellow
    $bad.Add([pscustomobject]@{ url=$u.AbsoluteUri; status=-1; location=""; error=$msg }) | Out-Null
  }

  $checked++
}

$result = [pscustomobject]@{
  checked      = $checked
  bad          = $bad.Count
  bad_list     = $bad
  visited      = $visited | Sort-Object
  scope_prefix = $PathPrefix
  base         = $Base
  start        = $Start
  ok_redirect  = $OkRedirectTo
  depth        = $Depth
  limit        = $Limit
}
$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$result | ConvertTo-Json -Depth 6 | Out-File -FilePath $Out -Encoding UTF8

if ($bad.Count -gt 0) {
  Write-Host ("[link-smoke] checked={0} bad={1} scope_prefix={2}" -f $checked, $bad.Count, $PathPrefix) -ForegroundColor Red
  $i = 0
  foreach ($b in $bad) {
    Write-Host ("    {0} {1} {2}" -f $i, $b.status, $b.url)
    $i++
  }
  exit 2
} else {
  Write-Host ("[link-smoke] checked={0} bad=0 scope_prefix={1}" -f $checked, $PathPrefix) -ForegroundColor Green
  Write-Host "[link-smoke] YEŞİL" -ForegroundColor Green
  exit 0
}
