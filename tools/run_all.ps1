param([string]$BindHost="127.0.0.1",[int]$Port=8000)
$ErrorActionPreference="Stop"

# Betiklerle aynÄ± klasÃ¶rde gÃ¼venli Ã§aÄŸrÄ±
$serve = Join-Path $PSScriptRoot 'serve_then_pipeline.ps1'
$accept = Join-Path $PSScriptRoot 'accept_visual.ps1'

powershell -ExecutionPolicy Bypass -File $serve -BindHost $BindHost -Port $Port
powershell -ExecutionPolicy Bypass -File $accept
