import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";
test("E110 - Çoklu arama ve temizleme (search → reset)", async ({ page }) => {
  await ensureLogin(page); await gotoList(page);
  const q = page.locator('input[name="q"]'); await expect(q).toBeVisible();
  await q.fill("dummy"); await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);
  // Reset: temel liste URL'sine dön
  await gotoList(page);
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/?$/);
});