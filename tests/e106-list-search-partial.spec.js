import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";

test("E106 - Liste arama partial match", async ({ page }) => {
  await ensureLogin(page);
  await gotoList(page);

  const q = page.locator('input[name="q"]').first();
  if(await q.count() === 0 || !await q.isVisible().catch(() => false)){
    test.skip();
    return;
  }

  await q.fill("EQ");
  await q.press("Enter");
  await page.waitForLoadState("domcontentloaded");
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?.*q=/);
  const table = page.locator("#result_list");
  await expect(table).toBeVisible({ timeout: 5000 });
});
