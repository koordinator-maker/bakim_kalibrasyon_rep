import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(30000);

test('E102 - Equipment Ekleme Formuna Erişim (debug)', async ({ page }) => {
  const addURL = `${BASE}/admin/maintenance/equipment/add/`;
  const resp = await page.goto(addURL, { waitUntil: 'domcontentloaded' });
  console.log('>>> nav status:', resp?.status(), 'final:', resp?.url());
  console.log('>>> url now:', page.url());

  // Listeye düşersek Add linkinden içeri gir
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }

  // Doğru form: _save butonunu içeren form
  const form = page.locator('form:has(input[name="_save"])').first();
  const count = await form.count();
  console.log('>>> form(has _save) count:', count);
  await expect(form, 'Admin add form görünür olmalı').toBeVisible();

  const saveBtn = form.locator('input[name="_save"]');
  await expect(saveBtn).toBeVisible();

  const h1 = (await page.locator('#content h1, main h1, h1').first().textContent().catch(()=>null))?.trim();
  console.log('>>> h1:', h1);
});