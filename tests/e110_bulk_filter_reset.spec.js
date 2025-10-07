import { test, expect } from '@playwright/test';
import { createTempEquipment, ensureLogin, gotoListExport } from './helpers_e10x.js';

test('E110 - Çoklu arama ve temizleme (search → reset)', async ({ page }) => {
  await ensureLogin(page);
  const token = `E110-${Date.now()}`;
  await createTempEquipment(page, token);
  await createTempEquipment(page, token);

  await gotoListExport(page);
  const q = page.locator('input[name="q"]');
  await expect(q).toBeVisible();
  await q.fill(token);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
    q.press('Enter'),
  ]);
  const rows = page.locator('#result_list tbody tr');
  const count = await rows.count();
  if (count < 2) throw new Error(`Beklenen en az 2 satır, bulundu: ${count}`);

  await q.fill('');
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
    q.press('Enter'),
  ]);
  await expect(page).not.toHaveURL(/\?q=/);
});
