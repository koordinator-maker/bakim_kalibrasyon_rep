[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepoRoot = $(git rev-parse --show-toplevel),
  [string]$DjangoManage = "manage.py",
  [string]$AdminUser = $env:ADMIN_USER,
  [string]$AdminPass = $env:ADMIN_PASS,
  [string]$AdminMail = "admin@example.com",
  [string]$BaseUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
trap { throw }
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if (-not $BaseUrl) { $BaseUrl = $env:BASE_URL }
if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:8010" }

function WriteUtf8NoBom($Path, $Text) {
  $full = Resolve-Path -LiteralPath $Path
  [IO.File]::WriteAllText($full, $Text, (New-Object Text.UTF8Encoding($false)))
}

function SafeReplace-InFile {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [string]$Pattern,
    [Parameter(Mandatory)] [string]$Replacement,
    [switch]$Multiline
  )
  if (!(Test-Path $Path)) { return $false }
  $raw = Get-Content $Path -Raw
  $opt = [System.Text.RegularExpressions.RegexOptions]::None
  if ($Multiline) { $opt = $opt -bor [System.Text.RegularExpressions.RegexOptions]::Singleline }
  $new = [Regex]::Replace($raw, $Pattern, $Replacement, $opt)
  if ($new -ne $raw) {
    Copy-Item $Path "$Path.bak" -Force
    WriteUtf8NoBom -Path $Path -Text $new
    return $true
  }
  return $false
}

Set-Location $RepoRoot
Write-Host "Repo: $RepoRoot"

$ModelsPath = Join-Path $RepoRoot "maintenance\models.py"
$AdminPath  = Join-Path $RepoRoot "maintenance\admin.py"
$UrlsPath   = Join-Path $RepoRoot "core\mw_fix_equip_redirect.py"

if (Test-Path $ModelsPath) {
  $models = Get-Content $ModelsPath -Raw
  if ($models -notmatch 'class\s+Equipment\s*\(') {
    Write-Warning "models.py içinde Equipment bulunamadı. Bu adımı atlıyorum."
  } else {
    $touched = $false
    $touched = $touched -bor (SafeReplace-InFile -Path $ModelsPath `
      -Pattern 'serial_number\s*=\s*models\.CharField\([^\)]*?unique\s*=\s*True[^\)]*?\)' `
      -Replacement 'serial_number = models.CharField(max_length=120, unique=True, blank=True, null=True)' )
    $touched = $touched -bor (SafeReplace-InFile -Path $ModelsPath `
      -Pattern 'serial_number\s*=\s*models\.CharField\([^\)]*?\)' `
      -Replacement 'serial_number = models.CharField(max_length=120, unique=True, blank=True, null=True)' )
    if ($touched) { Write-Host "[OK] models.py güncellendi (serial_number unique+nullable)." }
    else { Write-Host "[i] models.py serial_number satırı zaten uygun görünüyor." }
  }
} else {
  Write-Warning "models.py bulunamadı: $ModelsPath"
}

if (!(Test-Path $AdminPath)) {
$stub = @"
from django.contrib import admin
from .models import Equipment

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "serial_number")
    search_fields = ("name", "serial_number")
    # Add formunun engellenmediğinden emin olmak için:
    def has_add_permission(self, request):
        return True
"@
  New-Item -ItemType File -Path $AdminPath -Force | Out-Null
  WriteUtf8NoBom -Path $AdminPath -Text $stub
  Write-Host "[OK] admin.py oluşturuldu ve EquipmentAdmin eklendi."
} else {
  $raw = Get-Content $AdminPath -Raw
  if ($raw -notmatch 'from\s+\.models\s+import\s+.*Equipment') {
    $raw = "from .models import Equipment`r`n" + $raw
  }
  if ($raw -notmatch '@admin\.register\(\s*Equipment\s*\)' -and $raw -notmatch 'admin\.site\.register\(\s*Equipment') {
    $raw += "`r`n@admin.register(Equipment)`r`nclass EquipmentAdmin(admin.ModelAdmin):`r`n    list_display = (""id"",""name"",""serial_number"")`r`n"
  }
  $raw = [Regex]::Replace($raw, 'def\s+has_add_permission\([^\)]*\):\s*return\s+False', 'def has_add_permission(self, request):`r`n        return True')
  Copy-Item $AdminPath "$AdminPath.bak" -Force
  WriteUtf8NoBom -Path $AdminPath -Text $raw
  Write-Host "[OK] admin.py doğrulandı/güncellendi."
}

if (Test-Path $UrlsPath) {
  $added = SafeReplace-InFile -Path $UrlsPath -Multiline `
    -Pattern '(def\s+process_request\([^\)]*\)\s*:\s*.*?)(return\s+HttpResponseRedirect\([^\)]*\))' `
    -Replacement '$1
# /add/ yolu admin add view için bypass
try:
    path = request.get_full_path() if hasattr(request, "get_full_path") else request.path
except Exception:
    path = request.path
if path.endswith("/add/"):
    return None
$2'
  if ($added) { Write-Host "[OK] middleware add/bypass güncellendi." } else { Write-Host "[i] middleware değişikliğine gerek yok gibi." }
}

& .\venv\Scripts\python.exe $DjangoManage makemigrations
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& .\venv\Scripts\python.exe $DjangoManage migrate
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $AdminUser) { $AdminUser = "admin" }
if (-not $AdminPass) { $AdminPass = "admin123!" }

$py = @"
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.apps import apps
User = get_user_model()
u, created = User.objects.get_or_create(username='$AdminUser', defaults={'email':'$AdminMail','is_superuser':True,'is_staff':True})
if created:
    u.set_password('$AdminPass')
    u.save()
Equipment = apps.get_model('maintenance','Equipment')
if Equipment:
    ct = apps.get_model('contenttypes','ContentType').objects.get_for_model(Equipment)
    try:
        p = Permission.objects.get(codename='add_equipment', content_type=ct)
        u.user_permissions.add(p)
    except Permission.DoesNotExist:
        pass
print("OK-user:", u.username)
"@
$pyFile = Join-Path $RepoRoot "_otokodlama\ensure_admin.py"
New-Item -ItemType Directory -Path (Split-Path $pyFile) -Force | Out-Null
WriteUtf8NoBom -Path $pyFile -Text $py
& .\venv\Scripts\python.exe $DjangoManage shell -c "exec(open(r'$pyFile','r',encoding='utf-8').read())"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$addUrl = "$BaseUrl/admin/maintenance/equipment/add/"
try {
  $resp = Invoke-WebRequest -Uri $addUrl -MaximumRedirection 5 -ErrorAction Stop
  Write-Host "[HTTP] Status:" $resp.StatusCode "→ FinalUri:" $resp.BaseResponse.ResponseUri.AbsoluteUri
  $title = ([Regex]::Match($resp.Content, '<title[^>]*>(.*?)</title>', 'Singleline')).Groups[1].Value
  Write-Host "[HTTP] Title:" $title
} catch {
  Write-Warning "HTTP isteğinde hata: $($_.Exception.Message)"
}

$env:ALLOW_EQUIPMENT_ADD = "1"
$env:BASE_URL = $BaseUrl

# not: çıkış kodunu script dışından yönetelim (ayrı wrapper ile). Burada sadece hazırla.