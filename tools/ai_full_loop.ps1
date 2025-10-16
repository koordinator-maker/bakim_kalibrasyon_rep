# === AI TEST LOOP - Iteration Based ===
param([int]$MaxIterations = 10)

$ErrorActionPreference = 'Continue'
$repo = $PWD

function Write-Log($msg, $type='INFO'){
    $colors = @{'INFO'='Cyan';'SUCCESS'='Green';'WARN'='Yellow';'ERROR'='Red';'AI'='Magenta';'TEST'='Blue'}
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$ts][$type] $msg" -ForegroundColor $colors[$type]
}

function Run-Tests {
    Write-Log "Tests running..." "TEST"
    npx playwright test --reporter=html,line 2>&1 | Out-Null
    
    $reportJson = Get-ChildItem playwright-report -Recurse -Filter "report.json" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if(-not $reportJson){ return $null }
    
    $report = Get-Content $reportJson.FullName -Raw | ConvertFrom-Json
    $stats = @{Passed=0; Failed=0; Skipped=0}
    
    function Count($node){
        if($node.tests){
            foreach($t in $node.tests){
                if($t.status -eq 'passed'){ $stats.Passed++ }
                elseif($t.status -eq 'failed'){ $stats.Failed++ }
                else { $stats.Skipped++ }
            }
        }
        if($node.suites){ foreach($s in $node.suites){ Count $s } }
    }
    
    Count $report
    Write-Log "Results: $($stats.Passed) passed, $($stats.Failed) failed" "TEST"
    return $stats
}

function Create-AIPrompt($stats, $iteration){
    $prompt = @"
ITERATION $iteration - TEST ANALYSIS

Results: $($stats.Passed) PASSED, $($stats.Failed) FAILED

Provide PowerShell fixes for failing tests.
Format: Ready-to-run code blocks.
"@
    
    $path = "_otokodlama\reports\ai_iteration_${iteration}.txt"
    [System.IO.File]::WriteAllText("$PWD\$path", $prompt, [System.Text.UTF8Encoding]::new($false))
    
    Get-Content $path -Raw | Set-Clipboard
    Write-Log "Prompt ready: $path (copied to clipboard)" "AI"
    
    notepad $path
    return $path
}

# MAIN LOOP
Write-Host "`n=== AI LOOP START ===" -ForegroundColor Cyan

for($i = 1; $i -le $MaxIterations; $i++){
    Write-Log "=== ITERATION $i ===" "INFO"
    
    if($i -eq 1){
        Write-Log "First iteration: Get initial plan from AI" "INFO"
        $prompt = Create-AIPrompt -stats @{Passed=11;Failed=12;Skipped=4} -iteration 1
        
        Write-Host "`nPaste AI response here and press Enter (or 'q' to quit): " -NoNewline
        $response = Read-Host
        if($response -eq 'q'){ break }
        
    } else {
        $stats = Run-Tests
        if(-not $stats){ Write-Log "No test results!" "ERROR"; break }
        
        $prompt = Create-AIPrompt -stats $stats -iteration $i
        
        Write-Host "`nApply AI fixes and press Enter to continue (or 'q'): " -NoNewline
        $continue = Read-Host
        if($continue -eq 'q'){ break }
    }
}

Write-Host "`n=== AI LOOP COMPLETE ===" -ForegroundColor Green