param(
  [string]$TaskId,
  [string]$Description,
  [string[]]$Files = @()
)

$prompt = @"
Generate a maintenance patch for:

Task ID: $TaskId
Description: $Description
Files: $($Files -join ', ')

Return structured JSON patch with:
- patch_id
- summary
- files (path, action, changes, description)
- instructions
- validation
"@

@{
  model = "gpt-4o"
  messages = @(
    @{role="system"; content="You are a maintenance patch generator. Return responses in JSON format."},
    @{role="user"; content=$prompt}
  )
  temperature = 0.3
  max_tokens = 4000
} | ConvertTo-Json -Depth 10 | Set-Content "_otokodlama\out\$TaskId.json" -Encoding UTF8

Write-Host "[OK] Request olusturuldu: $TaskId (gpt-4o)" -ForegroundColor Green
