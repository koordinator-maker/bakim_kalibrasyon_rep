import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";
test("E105 - Liste arama (sade ve sağlam)", async ({ page }) => {
  await ensureLogin(page); await gotoList(page);
  const q = page.locator('input[name="q"]'); await expect(q).toBeVisible();
  await q.fill("AUTO"); await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?q=/);
  await expect.soft(page.locator("#result_list")).toBeVisible({ timeout: 5000 });
});