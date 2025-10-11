import { test, expect } from "@playwright/test";
import { createMinimalEquipment, successFlashExists, gotoList } from "./helpers_e10x.js";
test("E107 - Ekipmanı düzenle ve kaydet", async ({ page }) => {
  await createMinimalEquipment(page);
  if (!/\/admin\/maintenance\/equipment\/\d+\/change\/?/.test(page.url())) {
    await gotoList(page);
    await page.locator("#result_list tbody tr").first().click();
  }
  const name = page.locator('#id_name, input[name="name"]').first();
  await name.fill(`EQ-EDIT-${Date.now()}`);
  await Promise.all([ page.waitForLoadState("domcontentloaded"), page.locator('input[name="_save"], button[name="_save"]').first().click() ]);
  expect(await successFlashExists(page)).toBeTruthy();
});