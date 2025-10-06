import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(45000);

async function goToAdd(page) {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  
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
if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }
}

async function ensureOnChangePage(page, ts, primaryText) {
  if (/\/change\/?$/.test(page.url())) return true;

  const msgChange = page.locator('ul.messagelist a[href*="/change/"]');
  if (await msgChange.count()) {
    await msgChange.first().click();
    await page.waitForLoadState('domcontentloaded');
    if (/\/change\/?$/.test(page.url())) return true;
  }

  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: 'domcontentloaded' });
  let row = page.locator(`#result_list a:has-text("${ts}")`);
  if (!(await row.count()) && primaryText) {
    row = page.locator(`#result_list a:has-text("${primaryText}")`);
  }
  if (await row.count()) {
    await row.first().click();
    await page.waitForLoadState('domcontentloaded');
    return /\/change\/?$/.test(page.url());
  }
  return false;
}

test('E104 - Equipment oluÅŸtur ve sil (temizlik)', async ({ page }) => {
  await goToAdd(page);

  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form).toBeVisible();

  const ts = Date.now().toString();
  let primaryText = null;

  for (const sel of ['input[required][type="text"]','input[required]:not([type])','textarea[required]']) {
    const inputs = form.locator(sel);
    for (let i = 0; i < await inputs.count(); i++) {
      const el = inputs.nth(i);
      const name = (await el.getAttribute('name')) || `text${i}`;
      const val = name.toLowerCase().includes('serial') ? `SN-${ts}` : `AUTO-${name}-${ts}`;
      await el.fill(val);
      if (!primaryText) primaryText = val;
    }
  }

  const nums = form.locator('input[required][type="number"]');
  for (let i = 0; i < await nums.count(); i++) await nums.nth(i).fill('0');

  const today = new Date().toISOString().slice(0,10);
  const dates = form.locator('input[required][type="date"]');
  for (let i = 0; i < await dates.count(); i++) await dates.nth(i).fill(today);

  const selects = form.locator('select[required]');
  for (let i = 0; i < await selects.count(); i++) {
    await selects.nth(i).selectOption({ index: 1 }).catch(() => {});
  }

  await form.locator('input[name="_save"]').click();

  const onChange = await ensureOnChangePage(page, ts, primaryText);
  expect(onChange, 'KayÄ±t sonrasÄ± change sayfasÄ±na ulaÅŸÄ±lamadÄ±.').toBeTruthy();

  // Silme sayfasÄ±na git
  const deleteURL = page.url().replace(/change\/?$/, 'delete/');
  await page.goto(deleteURL, { waitUntil: 'domcontentloaded' });

  // YALNIZCA silme onay formu (iÃ§inde name="post" bulunur)
  const delForm = page.locator('#content form:has(input[name="post"])').first();
  await expect(delForm).toBeVisible();

  // Form iÃ§indeki submit
  await delForm.locator('input[type="submit"], button[type="submit"]').first().click();

  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/$/);
  await expect(page.locator('ul.messagelist li.success, .success')).toBeVisible();
});
