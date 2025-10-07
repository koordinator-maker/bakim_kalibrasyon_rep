import { test, expect } from "@playwright/test";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("E106 - Liste arama (partial match)", async ({ page }) => {
  const prefix = "AUTO-E106-";
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  const q = page.locator('input[name="q"]');
  await q.fill(prefix);
  await Promise.all([
    page.waitForLoadState("domcontentloaded"),
    page.keyboard.press("Enter"),
  ]);

  // En az bir sonuç bekle
  await expect(page.locator("#result_list tbody tr")).toHaveCountGreaterThan(0);
});