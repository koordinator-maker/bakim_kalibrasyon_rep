import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(30000);

test('E102 - Equipment Ekleme Formuna EriÅŸim (debug)', async ({ page }) => {
  const addURL = `${BASE}/admin/maintenance/equipment/add/`;
  const resp = await page.goto(addURL, { waitUntil: 'domcontentloaded' });
  
// --- ensure logged in (fallback) ---
if (/\/admin\/login\//.test(page.url())) {
  const uVal = process.env.ADMIN_USER ?? "admin";
  const pVal = process.env.ADMIN_PASS ?? "admin";

  // id/name/placeholder/label çoklu strateji
  let u = page.locator("#id_username, input[name=\\"username\\"], input[name=\\"email\\"], input#id_user, input[name=\\"user\\"]").first();
  const uByPh = page.getByPlaceholder(/kullanıcı adı|kullanici adi|email|e-?posta|username/i).first();
  const uByLb = page.getByLabel(/kullanıcı adı|kullanici adi|username|email|e-?posta/i).first();
  if (!(await u.isVisible().catch(()=>false))) u = (await uByPh.isVisible().catch(()=>false)) ? uByPh : uByLb;

  let p = page.locator("#id_password, input[name=\\"password\\"], input[type=\\"password\\"]").first();
  const pByPh = page.getByPlaceholder(/parola|şifre|sifre|password/i).first();
  const pByLb = page.getByLabel(/parola|şifre|sifre|password/i).first();
  if (!(await p.isVisible().catch(()=>false))) p = (await pByPh.isVisible().catch(()=>false)) ? pByPh : pByLb;

  try { await u.fill(uVal, { timeout: 10000 }); } catch {}
  try { await p.fill(pVal, { timeout: 10000 }); } catch {}

  const btn = page.getByRole("button", { name: /log in|giriş|oturum|sign in|submit|login/i }).first();
  if (await btn.isVisible().catch(()=>false)) { await btn.click(); }
  else {
    const submit = page.locator("input[type=\\"submit\\"], button[type=\\"submit\\"]").first();
    if (await submit.isVisible().catch(()=>false)) { await submit.click(); }
    else { await p.press("Enter").catch(()=>{}); }
  }
  await page.waitForLoadState("domcontentloaded").catch(()=>{});
}
// --- end ensure logged in ---
'.Trim()

$testFiles = @(
  '.\tests\e102_add_form.spec.js',
  '.\tests\e102_add_form_debug.spec.js',
  '.\tests\e104_create_and_delete_equipment.spec.js'
) | Where-Object { Test-Path $_ }

# page.goto("/admin/maintenance/equipment/add/") sonrasına enjekte et
$gotoPat = 'await\s+page\.goto\([^;]+/admin/maintenance/equipment/add/[^;]*\)\s*;'

foreach ($f in $testFiles) {
  $raw = Get-Content $f -Raw
  if ($raw -match $gotoPat) {
    $new = [regex]::Replace($raw, $gotoPat, { param($m) $m.Value + "`r`n" + $ensure + "`r`n" }, 1)
    if ($new -ne $raw) {
      [IO.File]::WriteAllText($f, $new, [Text.UTF8Encoding]::new($false))
      Write-Host "[OK] Login fallback enjekte edildi:" $f
    } else {
      Write-Host "[SKIP] Goto bulunamadı:" $f
    }
  } else {
    Write-Host "[SKIP] Desen eşleşmedi:" $f
  }
}


Set-Location C:\dev\bakim_kalibrasyon

# 1) Kaynakta manufacturer/uretici izini ara
"maintenance\models.py","maintenance\admin.py","maintenance\forms.py" | ForEach-Object {
  if (Test-Path $_) {
    Write-Host "`n### Scanning $_"
    Select-String -Path $_ -Pattern 'manufacturer|üretici|uretici' -CaseSensitive:$false | ForEach-Object { $_.Line }
  }
}

# 2) Örnek patch içeriği (manuel eklemek için hızlı şablon DOSYA YAZMAZ, sadece çıktı verir)
$adminPatch = @'
# maintenance/admin.py içinde EquipmentAdmin:
# class EquipmentAdmin(admin.ModelAdmin):
#     fields = ("name", "serial_number", "manufacturer", ...)
#     # veya fieldsets ile ilgili gruba ekleyin
console.log('>>> nav status:', resp?.status(), 'final:', resp?.url());
  console.log('>>> url now:', page.url());

  // Listeye dÃ¼ÅŸersek Add linkinden iÃ§eri gir
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }

  // DoÄŸru form: _save butonunu iÃ§eren form
  const form = page.locator('form:has(input[name="_save"])').first();
  const count = await form.count();
  console.log('>>> form(has _save) count:', count);
  await expect(form, 'Admin add form gÃ¶rÃ¼nÃ¼r olmalÄ±').toBeVisible();

  const saveBtn = form.locator('input[name="_save"]');
  await expect(saveBtn).toBeVisible();

  const h1 = (await page.locator('#content h1, main h1, h1').first().textContent().catch(()=>null))?.trim();
  console.log('>>> h1:', h1);
});