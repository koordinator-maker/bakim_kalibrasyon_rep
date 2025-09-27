param(
  [switch]$FailFast,
  [switch]$Soft
)
$ErrorActionPreference = "Stop"

$repo = Get-Location
$outD = Join-Path $repo "_otokodlama\out"
New-Item -ItemType Directory -Force -Path $outD | Out-Null

# BASE_URL garanti olsun (pipeline set ediyorsa bunu kullanır)
if (-not $env:BASE_URL -or [string]::IsNullOrWhiteSpace($env:BASE_URL)) {
  $env:BASE_URL = "http://127.0.0.1:8010"
}

# Koşturulacak flow listesi
$flows = @(
  "ops\flows\admin_home.flow",
  "ops\flows\admin_plan.flow",
  "ops\flows\admin_calibrations.flow",
  "ops\flows\admin_checklists.flow",
  "ops\flows\admin_equipment.flow"
) | Where-Object { Test-Path $_ }

$results = @()
$anyFail = $false

foreach ($flow in $flows) {
  $name = [IO.Path]::GetFileName($flow)
  $stem = [IO.Path]::GetFileNameWithoutExtension($flow)
  $json = Join-Path $outD ($stem + ".json")

  Write-Host "[FLOW] $flow"
  # Not: pw_flow.py BASE_URL ortam değişkenini kullanır
  & python tools\pw_flow.py --steps $flow --out $json
  $rc = $LASTEXITCODE

  $ok = $false
  $firstErr = $null
  if (Test-Path $json) {
    try {
      $j = Get-Content $json -Raw | ConvertFrom-Json
      $ok = [bool]$j.ok
      if (-not $ok -and $j.results) {
        $firstErr = ($j.results | Where-Object { -not $_.ok } | Select-Object -First 1)
      }
    } catch {
      $ok = $false
      $firstErr = @{ cmd="PARSE_JSON"; arg=$json; url=""; error=$_.Exception.Message }
    }
  } else {
    $ok = $false
    $firstErr = @{ cmd="NO_JSON"; arg=$json; url=""; error="json üretilmedi (rc=$rc)" }
  }

  if ($ok) {
    Write-Host "[FLOW] PASSED: $stem"
  } else {
    Write-Warning "[FLOW] FAILED: $stem"
    $anyFail = $true
    if ($FailFast -and -not $Soft) { break }
  }

  $results += [pscustomobject]@{
    name = $stem
    flow = $name
    ok   = $ok
    out  = ".\_otokodlama\out\$($stem).json"
    first_error = $firstErr
  }
}

elif cmd == "SELECT":
    # SELECT select#id_order_type label=Planlı
    # SELECT select#id_order_type value=PLN
    # SELECT select#id_equipment index=1
    parts = arg.split()
    if not parts:
        raise PWError("SELECT requires arguments")
    sel = parts[0]
    kv = {}
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            kv[k.strip().lower()] = v.strip()
    if not kv:
        raise PWError("SELECT needs value=... or label=... or index=...")
    opt = {}
    if "value" in kv: opt["value"] = kv["value"]
    if "label" in kv: opt["label"] = kv["label"]
    if "index" in kv: opt["index"] = int(kv["index"])
    page.select_option(sel, opt)

elif cmd == "EXPECTTEXT":
    # EXPECTTEXT label[for="id_title"] equals Başlık
    # EXPECTTEXT label[for="id_title"] contains Başlık
    parts = arg.split(None, 2)
    if len(parts) < 3:
        raise PWError("EXPECTTEXT <selector> <equals|contains> <text>")
    sel, mode, text = parts[0], parts[1].lower(), parts[2]
    actual = page.inner_text(sel).strip()
    if mode in ("equals", "=="):
        if actual != text:
            raise AssertionError(f'EXPECTTEXT equals failed: "{actual}" != "{text}"')
    elif mode in ("contains", "~="):
        if text not in actual:
            raise AssertionError(f'EXPECTTEXT contains failed: "{text}" not in "{actual}"')
    else:
        raise PWError(f"Unsupported EXPECTTEXT mode: {mode}")

elif cmd == "EXPECTVALUE":
    # EXPECTVALUE #id_order_type PLN
    parts = arg.split(None, 1)
    if len(parts) < 2:
        raise PWError("EXPECTVALUE <selector> <expected>")
    sel, expected = parts[0], parts[1]
    val = page.locator(sel).input_value()
    if val != expected:
        raise AssertionError(f'EXPECTVALUE failed: "{val}" != "{expected}"')

# flows_report.json: { "flows": [...] }
@{ flows = $results } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outD "flows_report.json") -Encoding utf8

if ($Soft) {
  exit 0
} else {
  if ($anyFail) { exit 1 } else { exit 0 }
}
