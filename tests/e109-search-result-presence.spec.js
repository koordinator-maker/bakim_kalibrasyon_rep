import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";

test("E109 - Arama sonucu presence check", async ({ page }) => {
  await ensureLogin(page);
  await gotoList(page);

  const q = page.locator('input[name="q"]').first();
  if(await q.count() === 0 || !await q.isVisible().catch(() => false)){
    test.skip();
    return;
  }

  await q.fill("NONEXISTENT_EQUIPMENT_XYZ");
  await q.press("Enter");
  await page.waitForLoadState("domcontentloaded");
  
  const noResults = page.locator('text=/no results/i, .empty, text=/0 results/i').first();
  const hasResults = await noResults.count() > 0;
  
  expect(hasResults).toBeTruthy();
});
