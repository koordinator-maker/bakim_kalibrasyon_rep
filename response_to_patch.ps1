# === response_to_patch.ps1 - OpenAI response'u patch'e çevir ===
param(
  [Parameter(Mandatory)][string]$ResponseFile,
  [string]$TaskId
)

if(!(Test-Path $ResponseFile)){ throw "Response dosyasi yok: $ResponseFile" }

# Response yükle
$data = Get-Content $ResponseFile -Raw | ConvertFrom-Json
$content = $data.choices[0].message.content

Write-Host "=== OpenAI Response to Patch ===" -ForegroundColor Cyan
Write-Host "Response: $($content.Substring(0, [Math]::Min(200, $content.Length)))..." -ForegroundColor Gray

# Patch dizini oluştur
$patchDir = "patch_${TaskId}_$(Get-Date -Format yyyyMMddHHmmss)"
$patchPath = "_otokodlama\temp\$patchDir"
New-Item -ItemType Directory -Force $patchPath | Out-Null

# AI cevabını patch olarak kaydet
$content | Set-Content "$patchPath\patch_content.txt" -Encoding UTF8

# JSON ise ayrıştır
try {
  $patchData = $content | ConvertFrom-Json
  
  if($patchData.files){
    # Dosya bazlı patch
    foreach($file in $patchData.files){
      $filePath = Join-Path $patchPath $file.path
      $fileDir = Split-Path $filePath -Parent
      if(!(Test-Path $fileDir)){ New-Item -ItemType Directory -Force $fileDir | Out-Null }
      
      $file.changes | Set-Content $filePath -Encoding UTF8
      Write-Host "[+] $($file.path)" -ForegroundColor Green
    }
  }
  
  # Instructions kaydet
  if($patchData.instructions){
    $patchData.instructions | Set-Content "$patchPath\INSTRUCTIONS.md" -Encoding UTF8
  }
  
  # JSON patch kaydet
  $patchData | ConvertTo-Json -Depth 10 | Set-Content "$patchPath\patch.json" -Encoding UTF8
  
} catch {
  Write-Host "[INFO] Serbest metin patch - manual review gerekli" -ForegroundColor Yellow
}

# ZIP oluştur
$zipPath = "_otokodlama\inbox\patch_${TaskId}_$(Get-Date -Format yyyyMMddHHmmss).zip"
Compress-Archive -Path "$patchPath\*" -DestinationPath $zipPath -Force
Write-Host "[OK] Patch olusturuldu: $zipPath" -ForegroundColor Green

# Cleanup
Remove-Item $patchPath -Recurse -Force

return $zipPath
