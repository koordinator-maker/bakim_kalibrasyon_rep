import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(20000);

test('E102 - Equipment Ekleme Formuna Erişim', async ({ page }) => {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });

  // Listeye düşersek "Add" linkiyle gir
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }

  // Doğru form: _save butonu olan form
  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form, 'Admin add form görünür olmalı').toBeVisible();

  // Birincil kaydet butonu
  await expect(form.locator('input[name="_save"]')).toBeVisible();

  // Başlık (bilgi amaçlı)
  await form.waitFor({ state: 'visible' });
  const h1 = await page.locator('#content h1, main h1, h1').first().textContent().catch(()=>null);
  console.log('H1:', h1?.trim());
});