param([int]$MaxIterations=3)

Write-Host "AI Loop Starting..." -ForegroundColor Cyan

for($i=1; $i -le $MaxIterations; $i++){
    Write-Host "`n=== Iteration $i ===" -ForegroundColor Yellow
    
    $dir = "_otokodlama"
    if(-not (Test-Path $dir)){ mkdir $dir }
    
    # Prompt
    "Iteration $i - Provide fixes" | Out-File "$dir\prompt_$i.txt"
    notepad "$dir\prompt_$i.txt"
    
    # Wait for response
    $response = "$dir\response_$i.ps1"
    Write-Host "Save response as: $response" -ForegroundColor Cyan
    
    while(-not (Test-Path $response)){
        Start-Sleep 5
        Write-Host "." -NoNewline
    }
    
    Write-Host "`nApplying..." -ForegroundColor Green
    & $response
}

Write-Host "`nDone!" -ForegroundColor Green