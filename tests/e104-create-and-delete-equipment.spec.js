import { test, expect } from "@playwright/test";
import { createMinimalEquipment, gotoList } from "./helpers_e10x.js";

test.setTimeout(60000);

test("E104 - Equipment oluştur ve sil (temizlik)", async ({ page }) => {
  await createMinimalEquipment(page);
  
  if (!/\/admin\/maintenance\/equipment\/\d+\/change\/?/.test(page.url())) {
    await gotoList(page);
    await page.locator("#result_list tbody tr").first().click();
  }
  
  await page.locator('a.deletelink, a[href*="/delete/"]').first().click();
  await page.locator('input[type="submit"][value*="Yes"]').click();
  await page.waitForLoadState("domcontentloaded");
  
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\//);
});

