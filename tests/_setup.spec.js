const { test, expect } = require('@playwright/test');
const fs = require('fs');

test('login state -> storage/user.json', async ({ page }) => {
  fs.mkdirSync('storage', { recursive: true });
  const base = process.env.BASE_URL || 'http://127.0.0.1:8010';
  const user = process.env.E2E_USER || 'admin';
  const pass = process.env.E2E_PASS || 'admin123!';

  // Django admin login
  await page.goto(`${base}/admin/login/?next=/admin/`);
  await page.fill('#id_username', user);
  await page.fill('#id_password', pass);
  await Promise.all([
    page.waitForNavigation(),
    page.click('input[type="submit"]'),
  ]);

  await expect(page).toHaveURL(/\/admin\/?$/);
  await page.context().storageState({ path: 'storage/user.json' });
});
