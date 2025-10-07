import { test, expect } from '@playwright/test';

const BASE = (process.env.BASE_URL || 'http://127.0.0.1:8010').replace(/\/$/, '');
test.setTimeout(30000);

test('E109 - Yetkisiz erişim: anonim kullanıcı add sayfasına erişemez', async ({ page }) => {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  await expect(page).toHaveURL(/\/admin\/login\//);
  await expect(page.locator('#id_username')).toBeVisible();
  await expect(page.locator('#id_password')).toBeVisible();
});
