import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(30000);

test('E102 - Equipment Ekleme Formuna Erişim (sağlam)', async ({ page }) => {
  const addURL = `${BASE}/admin/maintenance/equipment/add/`;
  await page.goto(addURL, { waitUntil: 'domcontentloaded' });

  // Eğer /add/ yerine listeye geldiysek, Add butonundan içeri gir
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
    }
  }

  // Artık add formunda olmalıyız
  await expect(page).toHaveURL(/\/add\/?$/);

  const form = page.locator('form[action*="/add/"], #content-main form, #content form, main form');
  await expect(form).toBeVisible();

  const saveBtn = page.locator("button[name='_save'], input[name*='_save'], button[type='submit'], input[type='submit']");
  await expect(saveBtn).toBeVisible();
});