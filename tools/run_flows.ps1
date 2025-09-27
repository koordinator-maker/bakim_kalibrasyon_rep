param(
  [switch],
  [switch]
)
\Continue = "Stop"

\ = Get-Location
\ = Join-Path \ "_otokodlama\out"
New-Item -ItemType Directory -Force -Path \ | Out-Null

# BASE_URL garanti olsun
if (-not \http://127.0.0.1:8010 -or [string]::IsNullOrWhiteSpace(\http://127.0.0.1:8010)) {
  \http://127.0.0.1:8010 = "http://127.0.0.1:8010"
}

# Koşturulacak flow listesi (klasörde varsa)
\ = @(
  "ops\flows\admin_home.flow",
  "ops\flows\admin_plan.flow",
  "ops\flows\admin_calibrations.flow",
  "ops\flows\admin_checklists.flow",
  "ops\flows\admin_equipment.flow",
  # Genel validatorlar:
  "ops\flows\admin_order_add_validate.flow",
  "ops\flows\admin_app_index_validate.flow"
) | Where-Object { Test-Path \ }

\ = @()
\ = \False

foreach (\# Admin > Equipment (click path; tolerate error pages)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
WAIT SELECTOR a[href="/admin/maintenance/equipment/"]
CLICK a[href="/admin/maintenance/equipment/"]
WAIT SELECTOR body
SCREENSHOT targets/screens/admin-equipment.png in \) {
  \ = [IO.Path]::GetFileName(\# Admin > Equipment (click path; tolerate error pages)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
WAIT SELECTOR a[href="/admin/maintenance/equipment/"]
CLICK a[href="/admin/maintenance/equipment/"]
WAIT SELECTOR body
SCREENSHOT targets/screens/admin-equipment.png)
  \ = [IO.Path]::GetFileNameWithoutExtension(\# Admin > Equipment (click path; tolerate error pages)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
WAIT SELECTOR a[href="/admin/maintenance/equipment/"]
CLICK a[href="/admin/maintenance/equipment/"]
WAIT SELECTOR body
SCREENSHOT targets/screens/admin-equipment.png)
  \ = Join-Path \ (\ + ".json")

  Write-Host "[FLOW] \# Admin > Equipment (click path; tolerate error pages)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
WAIT SELECTOR a[href="/admin/maintenance/equipment/"]
CLICK a[href="/admin/maintenance/equipment/"]
WAIT SELECTOR body
SCREENSHOT targets/screens/admin-equipment.png"
  & python tools\pw_flow.py --steps \# Admin > Equipment (click path; tolerate error pages)
GOTO /admin/login/
WAIT SELECTOR input#id_username
FILL input#id_username admin
FILL input#id_password Admin!2345
CLICK input[type=submit]
WAIT URL CONTAINS /admin/
WAIT SELECTOR a[href="/admin/maintenance/equipment/"]
CLICK a[href="/admin/maintenance/equipment/"]
WAIT SELECTOR body
SCREENSHOT targets/screens/admin-equipment.png --out \
  \ = \1

  \ = \False
  \ = \
  if (Test-Path \) {
    try {
      \ = Get-Content \ -Raw | ConvertFrom-Json
      \ = [bool]\.ok
      if (-not \ -and \.results) {
        \ = (\.results | Where-Object { -not \.ok } | Select-Object -First 1)
      }
    } catch {
      \ = \False
      \ = @{ cmd="PARSE_JSON"; arg=\; url=""; error=\.Exception.Message }
    }
  } else {
    \ = \False
    \ = @{ cmd="NO_JSON"; arg=\; url=""; error="json üretilmedi (rc=\)" }
  }

  if (\) {
    Write-Host "[FLOW] PASSED: \"
  } else {
    Write-Warning "[FLOW] FAILED: \"
    \ = \True
    if (\ -and -not \) { break }
  }

  \ += [pscustomobject]@{
    name = \
    flow = \
    ok   = \
    out  = ".\_otokodlama\out\.json"
    first_error = \
  }
}

# flows_report.json: { "flows": [...] }
@{ flows = \ } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path \ "flows_report.json") -Encoding utf8

if (\) {
  exit 0
} else {
  if (\) { exit 1 } else { exit 0 }
}