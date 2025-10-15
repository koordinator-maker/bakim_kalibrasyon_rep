param([string]$TaskId, [string]$Description)
@{
  task_id = $TaskId
  description = $Description
  files = @()
} | ConvertTo-Json | Set-Content "_otokodlama\out\$TaskId.json" -Encoding UTF8
Write-Host "[OK] Request olusturuldu: $TaskId"
