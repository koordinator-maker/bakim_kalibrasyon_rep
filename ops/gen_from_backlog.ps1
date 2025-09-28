param(
  [string]$BacklogPath = "ops\backlog.json",
  [string]$FlowsDir    = "ops\flows"
)

if (!(Test-Path $BacklogPath)) { throw "Backlog bulunamadı: $BacklogPath" }
$items = Get-Content $BacklogPath -Raw -Encoding UTF8 | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path $FlowsDir | Out-Null
New-Item -ItemType Directory -Force -Path _otokodlama\debug | Out-Null

function New-LoginBlock([object]$loginMeta) {
  $u = "/admin/login/"
  if ($null -ne $loginMeta.url -and $loginMeta.url) { $u = [string]$loginMeta.url }
@"
GOTO $u
WAIT SELECTOR input#id_username
FILL input#id_username $($loginMeta.username)
FILL input#id_password $($loginMeta.password)
CLICK input[type=submit]
WAIT SELECTOR body
DUMPDOM _otokodlama/debug/login_after_submit_dom.txt
SCREENSHOT _otokodlama/debug/login_after_submit.png
WAIT SELECTOR #user-tools a[href$="/logout/"]
"@
}

foreach ($it in $items) {
  $id = [string]$it.id
  if (-not $id) { continue }

  if ($it.type -eq "screen") {
    $login = if ($it.login) { $it.login } else { @{ username="admin"; password="Admin!2345"; url=$it.url } }
    $flow = New-LoginBlock -loginMeta $login
    if ($it.url) { $flow += "GOTO $($it.url)`n" }
    foreach ($sel in @($it.checks.must_have_selectors)) {
      if ($sel) { $flow += "WAIT SELECTOR $sel`n" }
    }
    $flow += "SCREENSHOT _otokodlama/debug/${id}_screen.png`n"
    $outPath = Join-Path $FlowsDir "${id}.flow"
    $flow | Set-Content $outPath -Encoding UTF8
    continue
  }

  if ($it.type -eq "crud_admin") {
    $urls = $it.urls
    $sel  = $it.selectors
    $dat  = $it.data
    $loginBlock = New-LoginBlock -loginMeta @{ username="admin"; password="Admin!2345"; url="/admin/login/" }

    # CREATE
    $create = $loginBlock + @"
GOTO $($urls.add)
WAIT SELECTOR $($sel.form)
FILL $($sel.code_input) $($dat.code)
FILL $($sel.name_input) $($dat.name)
CLICK input[name=_save]
WAIT SELECTOR $($sel.msg)
SCREENSHOT _otokodlama/debug/${id}_create.png
"@
    $createPath = Join-Path $FlowsDir "${id}_create.flow"
    $create | Set-Content $createPath -Encoding UTF8

    # UPDATE
    $update = $loginBlock + @"
GOTO $($urls.list_direct)?q=$($dat.search_q)
WAIT SELECTOR $($sel.list_table)
WAIT SELECTOR $($sel.row_link)
CLICK $($sel.row_link)
WAIT SELECTOR $($sel.form)
FILL $($sel.name_input) $($dat.name_updated)
CLICK input[name=_save]
WAIT SELECTOR $($sel.msg)
SCREENSHOT _otokodlama/debug/${id}_update.png
"@
    $updatePath = Join-Path $FlowsDir "${id}_update.flow"
    $update | Set-Content $updatePath -Encoding UTF8

    # DELETE
    $delete = $loginBlock + @"
GOTO $($urls.list_direct)?q=$($dat.search_q)
WAIT SELECTOR $($sel.list_table)
WAIT SELECTOR $($sel.row_link)
CLICK $($sel.row_link)
WAIT SELECTOR $($sel.delete_btn)
CLICK $($sel.delete_btn)
WAIT SELECTOR $($sel.delete_confirm)
CLICK $($sel.delete_confirm)
WAIT SELECTOR $($sel.msg)
SCREENSHOT _otokodlama/debug/${id}_delete.png
"@
    $deletePath = Join-Path $FlowsDir "${id}_delete.flow"
    $delete | Set-Content $deletePath -Encoding UTF8
  }
}

Write-Host "[gen] Flow üretimi tamam" -ForegroundColor Green
