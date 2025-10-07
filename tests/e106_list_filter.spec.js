import { test, expect } from '@playwright/test';
import { createTempEquipment, gotoListExport, ensureLogin } from './helpers_e10x.js';

test('E106 - Listeyi arama kutusuyla filtrele (token bazlı)', async ({ page }) => {
  await ensureLogin(page);
  const token = `E106-${Date.now()}`;
  await createTempEquipment(page, token);

  await gotoListExport(page);
  const q = page.locator('input[name="q"]');
  await expect(q).toBeVisible();
  await q.fill(token);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
    q.press('Enter'),
  ]);
  const rowLink = page.locator('#result_list a').filter({ hasText: token }).first();
  await expect(rowLink, 'Filtre sonucu beklenen kaydı göstermeli').toBeVisible();
});
