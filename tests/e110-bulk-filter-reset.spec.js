import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";

test("E110 - Filtre sıfırlama testi", async ({ page }) => {
  await ensureLogin(page);
  await gotoList(page);

  const q = page.locator('input[name="q"]').first();
  if(await q.count() === 0 || !await q.isVisible().catch(() => false)){
    test.skip();
    return;
  }

  await q.fill("FILTER_TEST");
  await q.press("Enter");
  await page.waitForLoadState("domcontentloaded");
  
  const clearLink = page.locator('a:has-text("Clear"), a:has-text("Reset"), a[href="/admin/maintenance/equipment/"]').first();
  if(await clearLink.count() > 0){
    await clearLink.click();
    await page.waitForLoadState("domcontentloaded");
    await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/$/);
  }
});
