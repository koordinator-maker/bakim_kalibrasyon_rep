import { test, expect } from '@playwright/test';
import fs from 'fs';

const base = process.env.BASE_URL || 'http://127.0.0.1:8010';
const user = process.env.E2E_USER || 'admin';
const pass = process.env.E2E_PASS || 'admin';
const storageFile = 'storage/user.json';

test.setTimeout(60_000);

test('login state -> storage/user.json', async ({ page, context }) => {
  // Varsa açık session'ı temizle
  await page.goto(`${base}/admin/logout/`).catch(() => {});
  // Admin login
  await page.goto(`${base}/admin/login/?next=/admin/`, { waitUntil: 'domcontentloaded' });

  const userInput = page.locator('#id_username').or(page.getByLabel(/Username|Kullanıcı adı/i));
  await expect(userInput).toBeVisible({ timeout: 15_000 });
  await userInput.fill(user);

  const passInput = page.locator('#id_password').or(page.getByLabel(/Password|Parola|Şifre/i));
  await expect(passInput).toBeVisible();
  await passInput.fill(pass);

  await Promise.all([
    page.waitForNavigation(),
    page.getByRole('button', { name: /log in|giriş|oturum/i }).or(page.locator('input[type=submit]')).click(),
  ]);

  await expect(page).toHaveURL(new RegExp(`${base.replace(/\//g, '\\/')}/admin/?`));

  fs.mkdirSync('storage', { recursive: true });
  await context.storageState({ path: storageFile });
});