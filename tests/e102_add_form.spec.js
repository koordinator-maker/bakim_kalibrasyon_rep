import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(20000);

test('E102 - Equipment Ekleme Formuna EriÃƒâ€¦Ã…Â¸im', async ({ page }) => {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });

  
// --- ensure logged in (fallback) ---
if (/\/admin\/login\//.test(page.url())) {
  const uVal = process.env.ADMIN_USER ?? "admin";
  const pVal = process.env.ADMIN_PASS ?? "admin";

  let u = page.locator('#id_username, input[name="username"], input[name="email"], input#id_user, input[name="user"]').first();
  const uByPh = page.getByPlaceholder(/kullanÄ±cÄ± adÄ±|kullanici adi|email|e-?posta|username/i).first();
  const uByLb = page.getByLabel(/kullanÄ±cÄ± adÄ±|kullanici adi|username|email|e-?posta/i).first();
  if (!(await u.isVisible().catch(()=>false))) u = (await uByPh.isVisible().catch(()=>false)) ? uByPh : uByLb;

  let p = page.locator('#id_password, input[name="password"], input[type="password"]').first();
  const pByPh = page.getByPlaceholder(/parola|ÅŸifre|sifre|password/i).first();
  const pByLb = page.getByLabel(/parola|ÅŸifre|sifre|password/i).first();
  if (!(await p.isVisible().catch(()=>false))) p = (await pByPh.isVisible().catch(()=>false)) ? pByPh : pByLb;

  try { await u.fill(uVal, { timeout: 10000 }); } catch {}
  try { await p.fill(pVal, { timeout: 10000 }); } catch {}

  const btn = page.getByRole("button", { name: /log in|giriÅŸ|oturum|sign in|submit|login/i }).first();
  if (await btn.isVisible().catch(()=>false)) { await btn.click(); }
  else {
    const submit = page.locator('input[type="submit"], button[type="submit"]').first();
    if (await submit.isVisible().catch(()=>false)) { await submit.click(); }
    else { await p.press("Enter").catch(()=>{}); }
  }
  await page.waitForLoadState("domcontentloaded").catch(()=>{});
  // login sonrası hâlâ add sayfasında değilsek, zorla dön
  try {
    const base = (process.env.BASE_URL || "").replace(/\/$/, "");
    if (base && !/\/admin\/maintenance\/equipment\/add\/?$/.test(page.url())) {
      await page.goto(base + "/admin/maintenance/equipment/add/", { waitUntil: "domcontentloaded" });
    }
  } catch {}
}
// --- end ensure logged in ---
'.Trim()

$testFiles = @(
  '.\tests\e102_add_form.spec.js',
  '.\tests\e102_add_form_debug.spec.js',
  '.\tests\e104_create_and_delete_equipment.spec.js'
) | Where-Object { Test-Path $_ }

# page.goto("/admin/maintenance/equipment/add/") sonrasÃ„Â±na enjekte et
$gotoPat = 'await\s+page\.goto\([^;]+/admin/maintenance/equipment/add/[^;]*\)\s*;'

foreach ($f in $testFiles) {
  $raw = Get-Content $f -Raw
  if ($raw -match $gotoPat) {
    $new = [regex]::Replace($raw, $gotoPat, { param($m) $m.Value + "`r`n" + $ensure + "`r`n" }, 1)
    if ($new -ne $raw) {
      [IO.File]::WriteAllText($f, $new, [Text.UTF8Encoding]::new($false))
      Write-Host "[OK] Login fallback enjekte edildi:" $f
    } else {
      Write-Host "[SKIP] Goto bulunamadÃ„Â±:" $f
    }
  } else {
    Write-Host "[SKIP] Desen eÃ…Å¸leÃ…Å¸medi:" $f
  }
}


Set-Location C:\dev\bakim_kalibrasyon

# 1) Kaynakta manufacturer/uretici izini ara
"maintenance\models.py","maintenance\admin.py","maintenance\forms.py" | ForEach-Object {
  if (Test-Path $_) {
    Write-Host "`n### Scanning $_"
    Select-String -Path $_ -Pattern 'manufacturer|ÃƒÂ¼retici|uretici' -CaseSensitive:$false | ForEach-Object { $_.Line }
  }
}

# 2) Ãƒâ€“rnek patch iÃƒÂ§eriÃ„Å¸i (manuel eklemek iÃƒÂ§in hÃ„Â±zlÃ„Â± Ã…Å¸ablon DOSYA YAZMAZ, sadece ÃƒÂ§Ã„Â±ktÃ„Â± verir)
$adminPatch = @'
# maintenance/admin.py iÃƒÂ§inde EquipmentAdmin:
# class EquipmentAdmin(admin.ModelAdmin):
#     fields = ("name", "serial_number", "manufacturer", ...)
#     # veya fieldsets ile ilgili gruba ekleyin
// Listeye dÃƒÆ’Ã‚Â¼Ãƒâ€¦Ã…Â¸ersek "Add" linkiyle gir
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }

  // DoÃƒâ€Ã…Â¸ru form: _save butonu olan form
  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form, 'Admin add form gÃƒÆ’Ã‚Â¶rÃƒÆ’Ã‚Â¼nÃƒÆ’Ã‚Â¼r olmalÃƒâ€Ã‚Â±').toBeVisible();

  // Birincil kaydet butonu
  await expect(form.locator('input[name="_save"]')).toBeVisible();

  // BaÃƒâ€¦Ã…Â¸lÃƒâ€Ã‚Â±k (bilgi amaÃƒÆ’Ã‚Â§lÃƒâ€Ã‚Â±)
  await form.waitFor({ state: 'visible' });
  const h1 = await page.locator('#content h1, main h1, h1').first().textContent().catch(()=>null);
  console.log('H1:', h1?.trim());
});