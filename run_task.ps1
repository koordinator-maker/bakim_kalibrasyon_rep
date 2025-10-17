param([string]$TaskId)
& .\load_env.ps1
& .\ops\loop_ai_verbose.ps1 -Mode direct -MaxRounds 1 -TaskId $TaskId
. .\ops\quarantine.ps1
Get-Quarantine -TaskId $TaskId | Format-List
