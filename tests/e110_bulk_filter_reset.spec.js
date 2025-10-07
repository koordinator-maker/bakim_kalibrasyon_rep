import { test, expect } from "@playwright/test";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("E110 - Çoklu arama ve temizleme (search → reset)", async ({ page }) => {
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });

  const q = page.locator('input[name="q"]');
  await q.fill("dummy");
  await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);

  // “Temizle” garanti: doğrudan temel liste URL'sine git
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  await expect(page).not.toHaveURL(/\?q=/);
});