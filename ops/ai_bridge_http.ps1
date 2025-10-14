param(
  [string]$TaskId = "UH001",
  [string]$RequestsDir = ".",
  [string]$OutDir = "_otokodlama\\inbox"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
# Guard
if(-not $env:AI_ENDPOINT -or -not $env:AI_API_KEY){ throw "AI_ENDPOINT / AI_API_KEY env değişkenlerini ayarla." }
$baseUrl = $env:AI_ENDPOINT.TrimEnd('/')
$pollSec = [int](if($env:AI_POLL_SEC){$env:AI_POLL_SEC}else{'5'})
$timeout = [int](if($env:AI_TIMEOUT_MIN){$env:AI_TIMEOUT_MIN}else{'8'})
# Son ai_request + bundle'ı bul
$root = (Get-Location).Path
$prefer = Join-Path $root ("ai_exchange\"+$TaskId)
$searchBase = if(Test-Path $prefer){$prefer}else{(Resolve-Path $RequestsDir).Path}
$latest = Get-ChildItem $searchBase -Directory -ErrorAction SilentlyContinue | Sort LastWriteTime -Descending | Select -First 1
if(-not $latest){ throw "ai_exchange/$TaskId altında paket yok." }
$reqJson = Get-ChildItem $latest.FullName -Filter "ai_request_*.json" -File | Sort LastWriteTime -Desc | Select -First 1
$bundle  = Get-ChildItem $latest.FullName -Filter "bundle_*.zip"      -File | Sort LastWriteTime -Desc | Select -First 1
if(-not $reqJson){ throw "ai_request_*.json bulunamadı: $($latest.FullName)" }
# 1) Upload: multipart/form-data dene; olmazsa JSON (base64) fallback
$hdr = @{ Authorization = "Bearer $($env:AI_API_KEY)" }
$uploadOk = $false; $resp = $null
try {
  $form = @{
    "task_id"     = $TaskId
    "request_json"= Get-Item -LiteralPath $reqJson.FullName
    "bundle_zip"  = $(if($bundle){ Get-Item -LiteralPath $bundle.FullName } else { $null })
  }
  $resp = Invoke-RestMethod -Method Post -Uri ($baseUrl+"/requests") -Headers $hdr -Form $form -TimeoutSec 120
  $uploadOk = $true
} catch {
  # Fallback: JSON + base64 (endpoint böyle istiyorsa)
  try {
    $payload = @{
      task_id = $TaskId
      request = (Get-Content -LiteralPath $reqJson.FullName -Raw)
      bundle_b64 = $(if($bundle){ [Convert]::ToBase64String([IO.File]::ReadAllBytes($bundle.FullName)) } else { $null })
      filename   = $(if($bundle){ Split-Path -Leaf $bundle.FullName } else { $null })
    } | ConvertTo-Json -Depth 12
    $resp = Invoke-RestMethod -Method Post -Uri ($baseUrl+"/requests") -Headers ($hdr + @{ "Content-Type"="application/json" }) -Body $payload -TimeoutSec 120
    $uploadOk = $true
  } catch {
    throw "Upload başarısız: $($_.Exception.Message)"
  }
}
# 2) Poll: status endpoint → completed + patch_url bekle
if(-not $uploadOk){ throw "Upload başarısız (bilinmeyen)." }
$id = if($resp.id){ $resp.id } elseif($resp.request_id){ $resp.request_id } else { $null }
if(-not $id){ throw "Yanıt id içermiyor: $(($resp|ConvertTo-Json -Depth 6))" }
$deadline = (Get-Date).AddMinutes($timeout)
$patchUrl = $null; $aiResult = $null
do {
  Start-Sleep -Seconds $pollSec
  $st = Invoke-RestMethod -Method Get -Uri ($baseUrl+"/requests/"+$id) -Headers $hdr -TimeoutSec 60
  $status = ($st.status+"").ToLower()
  if($st.result){ $aiResult = $st.result } # skorlayacağız
  if($st.patch_url){ $patchUrl = $st.patch_url }
  if($status -eq "completed" -and $patchUrl){ break }
  if($status -eq "failed"){ throw "AI servis failed: $($st.error)" }
} while((Get-Date) -lt $deadline)
if(-not $patchUrl){ throw "Zaman aşımı: patch_url gelmedi." }
# 3) İndir: patch.zip → OutDir
if(!(Test-Path $OutDir)){ New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$outZip = Join-Path $OutDir ("patch_"+$TaskId+"_"+$ts+".zip")
Invoke-WebRequest -UseBasicParsing -Uri $patchUrl -Headers $hdr -OutFile $outZip -TimeoutSec 300
# 4) (Opsiyonel) AI yanıtını kaydet ve skorla
if($aiResult){
  $resPath = Join-Path $latest.FullName ("ai_result_"+$TaskId+"_"+$ts+".json")
  [IO.File]::WriteAllText($resPath, ($aiResult|ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
  try {
    powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\\ai_response_validator.ps1" -TaskId $TaskId -ResultJson $resPath -MinScore 0.9
  } catch {
    Write-Host "[warn] validator: $($_.Exception.Message)"
  }
}
Write-Host "[http] patch indirildi: $((Resolve-Path $outZip).Path)"