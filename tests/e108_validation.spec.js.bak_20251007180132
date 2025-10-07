import { test, expect } from '@playwright/test';
import { ensureLogin } from './helpers_e10x.js';
import { createTempEquipment } from './helpers_e10x.js';

test('E108 - Zorunlu alan doğrulaması (boş gönderimde hata beklenir)', async ({ page }) => {
  await ensureLogin(page);
  // go to add and submit empty
  await page.goto(`${(process.env.BASE_URL||'http://127.0.0.1:8010').replace(/\/$/,'')}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  const submit = page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await submit.click();
  const anyError = page.locator('.errorlist, .errors, .invalid-feedback, .field-error, .errornote');
  await expect(anyError.first(), 'Boş gönderimde doğrulama hatası beklenir').toBeVisible();
});
