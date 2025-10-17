# === ai_bridge_http.ps1 (PowerShell 7 - TLS 1.2 explicit) ===
param(
  [Parameter(Mandatory=$false)][string]$RequestsDir = "_otokodlama\out",
  [Parameter(Mandatory=$false)][string]$InboxDir    = "_otokodlama\inbox",
  [Parameter(Mandatory=$true)][string]$TaskId
)
$ErrorActionPreference='Stop'

# === TLS 1.2 EXPLICIT (PS7) ===
$PSDefaultParameterValues = @{
  'Invoke-RestMethod:SslProtocol' = 'Tls12'
  'Invoke-WebRequest:SslProtocol' = 'Tls12'
}

# === CONFIG ===
$endpoint       = $env:AI_ENDPOINT
$statusTemplate = $env:AI_STATUS_TEMPLATE
$apiKey         = $env:AI_API_KEY
$authHeader     = if($env:AI_AUTH_HEADER){ $env:AI_AUTH_HEADER } else { 'Authorization' }
$pollMode       = if($env:AI_POLL_MODE){ $env:AI_POLL_MODE.ToLower() } else { '' }
$pollInterval   = if($env:AI_POLL_INTERVAL){ [int]$env:AI_POLL_INTERVAL } else { 5 }
$pollTimeout    = if($env:AI_POLL_TIMEOUT){ [int]$env:AI_POLL_TIMEOUT } else { 300 }

if([string]::IsNullOrWhiteSpace($endpoint)){ throw 'AI_ENDPOINT bos' }

Write-Host "=== AI Bridge HTTP ===" -ForegroundColor Cyan
Write-Host "TaskId: $TaskId"
Write-Host "Endpoint: $endpoint"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# 1) REQUEST JSON
$reqPath = Join-Path $RequestsDir "$TaskId.json"
if(!(Test-Path $reqPath)){ throw "Request JSON yok: $reqPath" }
$reqJson = Get-Content $reqPath -Raw | ConvertFrom-Json

# 2) SUBMIT
Write-Host "Submitting to $endpoint ..."

$uploadOk = $false; $id = $null
try {
  $headers = @{'Content-Type'='application/json'}
  if(![string]::IsNullOrWhiteSpace($apiKey)){
    $headers[$authHeader] = "Bearer $apiKey"
  }
  
  $body = $reqJson | ConvertTo-Json -Compress -Depth 10
  $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -Headers $headers
  
  Write-Host "Submit OK" -ForegroundColor Green  
  # OpenAI response'u kaydet
  $responsePath = Join-Path $InboxDir "response_${TaskId}_$(Get-Date -Format yyyyMMddHHmmss).json"
  if(!(Test-Path $InboxDir)){ New-Item -ItemType Directory -Force $InboxDir | Out-Null }
  $response | ConvertTo-Json -Depth 10 | Set-Content $responsePath -Encoding UTF8
  Write-Host "Response saved -> $responsePath" -ForegroundColor Gray
  
  # Extract ID
  foreach($k in 'id','run_id','request_id'){
    if($response.PSObject.Properties.Name -contains $k -and $response.$k){
      $id = [string]$response.$k
      break
    }
  }
  if(-not $id){
    $id = "mock-{0:yyyyMMddHHmmss}" -f (Get-Date)
    Write-Host "No ID; fallback = $id" -ForegroundColor Yellow
  } else {
    Write-Host "ID = $id" -ForegroundColor Green
  }
  $uploadOk = $true
} catch {
  Write-Host "Submit FAIL: $($_.Exception.Message)" -ForegroundColor Red
  if($_.ErrorDetails.Message){
    Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
  }
}

if(-not $uploadOk){ throw 'AI submit failed' }

# 3) POLL-SKIP
if($pollMode -eq 'skip'){
  Write-Host 'Poll skipped' -ForegroundColor Gray
  return
}

# 4) POLL STATUS
if([string]::IsNullOrWhiteSpace($statusTemplate)){
  Write-Host 'No status template; skipping poll' -ForegroundColor Gray
  return
}

$statusUrl = $statusTemplate -replace '\{id\}', $id
Write-Host "Polling: $statusUrl ..." -ForegroundColor Cyan

$start = Get-Date
while(((Get-Date) - $start).TotalSeconds -lt $pollTimeout){
  Start-Sleep -Seconds $pollInterval
  
  try {
    $headers2 = @{}
    if(![string]::IsNullOrWhiteSpace($apiKey)){
      $headers2[$authHeader] = "Bearer $apiKey"
    }
    
    $sobj = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $headers2
    $st = $sobj.status
    Write-Host "Status = $st" -ForegroundColor Gray
    
    if($st -match 'complete|done|success|succeeded'){
      if($sobj.patch_url){
        $purl = $sobj.patch_url
        Write-Host "Patch URL = $purl" -ForegroundColor Green
        
        $pname = "patch_${TaskId}_$(Get-Date -Format yyyyMMddHHmmss).zip"
        $ppath = Join-Path $InboxDir $pname
        
        if(!(Test-Path $InboxDir)){ New-Item -ItemType Directory -Force $InboxDir | Out-Null }
        
        Invoke-RestMethod -Uri $purl -OutFile $ppath -Headers $headers2
        Write-Host "Patch downloaded -> $ppath" -ForegroundColor Green
        return
      } else {
        Write-Host 'Complete but no patch_url' -ForegroundColor Yellow
        return
      }
    }
    if($st -match 'fail|error'){
      throw "AI task failed: $st"
    }
  } catch {
    Write-Host "Poll error: $($_.Exception.Message)" -ForegroundColor Red
  }
}
Write-Host "Poll timeout ($pollTimeout s)" -ForegroundColor Red
throw 'AI poll timeout'