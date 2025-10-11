import { test, expect } from "@playwright/test";
import { createMinimalEquipment, successFlashExists, gotoList } from "./helpers_e10x.js";
test("E104 - Equipment oluştur ve sil (temizlik)", async ({ page }) => {
  await createMinimalEquipment(page);
  if (!/\/admin\/maintenance\/equipment\/\d+\/change\/?/.test(page.url())) {
    await gotoList(page);
    await page.locator("#result_list tbody tr").first().click();
  }
  const del = page.locator('a.deletelink, .deletelink').first().or(page.getByRole('link', { name: /delete|sil/i }).first());
  await del.click();
  const yes = page.getByRole('button', { name: /delete|sil/i }).first().or(page.locator('input[type="submit"]').first());
  await Promise.all([ page.waitForLoadState("domcontentloaded"), yes.click() ]);
  expect(await successFlashExists(page)).toBeTruthy();
});