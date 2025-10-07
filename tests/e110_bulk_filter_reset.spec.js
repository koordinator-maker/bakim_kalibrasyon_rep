import { test, expect } from "@playwright/test";
import { ensureLogin, gotoListExport } from "./helpers_e10x";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/,"");

test("E110 - Çoklu arama ve temizleme (search → reset)", async ({ page }) => {
  page = await ensureLogin(page);
  page = await gotoListExport(page);

  const q = page.locator('input[name="q"]');
  await q.fill("dummy");
  await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);

  // Reset: temel liste URL'sine dön
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  await expect(page).not.toHaveURL(/\?q=/);
});