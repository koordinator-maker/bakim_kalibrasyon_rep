import { test, expect } from '@playwright/test';

// Ayarlar (ENV varsa onları kullan)
const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
const USER = process.env.E2E_USER || 'admin';
const PASS = process.env.E2E_PASS || 'admin123!';

// Zor durumlar için zaman aşımı biraz geniş
test.setTimeout(30000);

test('login state -> storage/user.json', async ({ page, context }) => {
  // /admin/ -> zaten login ise admin index, değilse login sayfasına yönlendirir
  await page.goto(`${BASE}/admin/`, { waitUntil: 'domcontentloaded' });

  const userInput = page.locator('#id_username');
  const passInput = page.locator('#id_password');

  // Login formu görünüyor mu?
  const onLogin = (await userInput.count()) > 0;

  if (onLogin) {
    await userInput.fill(USER);
    await passInput.fill(PASS);
    await page.click('input[type="submit"]');
    await expect(page).toHaveURL(/\/admin\/?$/);
  } else {
    // Zaten giriş yapmış durumda
    await expect(page).toHaveURL(/\/admin\/?$/);
  }

  await context.storageState({ path: 'storage/user.json' });
  console.log(`[SETUP SUCCESS] Saved: storage/user.json — URL: ${await page.url()}`);
});