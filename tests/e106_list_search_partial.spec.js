import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";
test("E106 - Liste arama (partial match)", async ({ page }) => {
  await ensureLogin(page); await gotoList(page);
  const q = page.locator('input[name="q"]'); await expect(q).toBeVisible();
  const term = "AUTO"; await q.fill(term);
  await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?q=/);
  await expect(q).toHaveValue(term);
});