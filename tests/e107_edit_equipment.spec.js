import { test, expect } from '@playwright/test';
import { createTempEquipment, ensureLogin } from './helpers_e10x.js';

test('E107 - Ekipmanı düzenle ve kaydet', async ({ page }) => {
  await ensureLogin(page);
  const { token } = await createTempEquipment(page);
  const firstText = page.locator('form input[type="text"], form textarea').first();
  await expect(firstText).toBeVisible();
  const newVal = `EDITED-${token}`;
  await firstText.fill(newVal);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
    page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first().click()
  ]);
  await expect(page.locator('ul.messagelist li.success, .success')).toBeVisible();
});
