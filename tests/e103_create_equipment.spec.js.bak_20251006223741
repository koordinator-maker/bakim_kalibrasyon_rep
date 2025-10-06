import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(45000);

test('E103 - Equipment Kaydetme (dinamik doldurma)', async ({ page }) => {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });

  // Gerekirse listeden "Add" ile içeri gir
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }

  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form).toBeVisible();

  const ts = Date.now().toString();

  // Metin alanları (required)
  for (const sel of [
    'input[required][type="text"]',
    'input[required]:not([type])',
    'textarea[required]'
  ]) {
    const inputs = form.locator(sel);
    const n = await inputs.count();
    for (let i = 0; i < n; i++) {
      const el = inputs.nth(i);
      const name = (await el.getAttribute('name')) || `text${i}`;
      const val = name.toLowerCase().includes('serial') ? `SN-${ts}` : `AUTO-${name}-${ts}`;
      await el.fill(val);
    }
  }

  // Number
  const nums = form.locator('input[required][type="number"]');
  for (let i = 0; i < await nums.count(); i++) {
    await nums.nth(i).fill('0');
  }

  // Tarih (HTML5 date)
  const today = new Date().toISOString().slice(0,10);
  const dates = form.locator('input[required][type="date"]');
  for (let i = 0; i < await dates.count(); i++) {
    await dates.nth(i).fill(today);
  }

  // Select (first non-empty option)
  const selects = form.locator('select[required]');
  for (let i = 0; i < await selects.count(); i++) {
    const sel = selects.nth(i);
    // index:1 genelde ilk geçerli seçenek
    await sel.selectOption({ index: 1 }).catch(()=>{});
  }

  // Kaydet
  await form.locator('input[name="_save"]').click();

  // Başarı doğrulama: /change/ URL'i veya başarı mesajı
  const urlOk = page.waitForURL(/\/equipment\/\d+\/change\/$/, { timeout: 8000 }).catch(()=>null);
  const msgOk = page.locator('ul.messagelist li.success, .success').first();
  await Promise.race([
    urlOk,
    msgOk.waitFor({ state: 'visible', timeout: 8000 }).catch(()=>null)
  ]);

  // En az biri doğrulansın
  const inChange = /\/equipment\/\d+\/change\/$/.test(page.url());
  const hasMsg = await msgOk.isVisible().catch(()=>false);
  expect(inChange || hasMsg, 'Kayıt sonrası change sayfası veya başarı mesajı beklenirdi.').toBeTruthy();
});