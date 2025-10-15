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

# Markdown code block temizle
$content = $content -replace '```json\s*', '' -replace '```\s*$', '' -replace '```', ''
$content = $content.Trim()

Write-Host "Response length: $($content.Length) chars" -ForegroundColor Gray

# Patch dizini oluştur
$patchDir = "patch_${TaskId}_$(Get-Date -Format yyyyMMddHHmmss)"
$patchPath = "_otokodlama\temp\$patchDir"
New-Item -ItemType Directory -Force $patchPath | Out-Null

# AI cevabını patch olarak kaydet
$content | Set-Content "$patchPath\patch_content.txt" -Encoding UTF8

# JSON parse
try {
  $patchData = $content | ConvertFrom-Json
  Write-Host "[OK] JSON parse basarili!" -ForegroundColor Green
  
  if($patchData.files){
    # Dosya bazlı patch
    foreach($file in $patchData.files){
      $filePath = Join-Path $patchPath $file.path
      $fileDir = Split-Path $filePath -Parent
      if($fileDir -and !(Test-Path $fileDir)){ 
        New-Item -ItemType Directory -Force $fileDir | Out-Null 
      }
      
      $file.changes | Set-Content $filePath -Encoding UTF8
      Write-Host "[+] $($file.path)" -ForegroundColor Green
    }
  }
  
  # Instructions kaydet
  if($patchData.instructions){
    $patchData.instructions | Set-Content "$patchPath\INSTRUCTIONS.md" -Encoding UTF8
    Write-Host "[+] INSTRUCTIONS.md" -ForegroundColor Green
  }
  
  # Validation kaydet
  if($patchData.validation){
    $patchData.validation | Set-Content "$patchPath\VALIDATION.md" -Encoding UTF8
    Write-Host "[+] VALIDATION.md" -ForegroundColor Green
  }
  
  # JSON patch kaydet
  $patchData | ConvertTo-Json -Depth 10 | Set-Content "$patchPath\patch.json" -Encoding UTF8
  Write-Host "[+] patch.json" -ForegroundColor Green
  
} catch {
  Write-Host "[WARN] JSON parse hatasi: $($_.Exception.Message)" -ForegroundColor Yellow
  Write-Host "[INFO] Serbest metin patch - manual review gerekli" -ForegroundColor Yellow
}

# ZIP oluştur
$zipPath = "_otokodlama\inbox\patch_${TaskId}_$(Get-Date -Format yyyyMMddHHmmss).zip"
Compress-Archive -Path "$patchPath\*" -DestinationPath $zipPath -Force
Write-Host "[OK] Patch ZIP olusturuldu: $(Split-Path $zipPath -Leaf)" -ForegroundColor Green

# Cleanup
Remove-Item $patchPath -Recurse -Force

return $zipPath
