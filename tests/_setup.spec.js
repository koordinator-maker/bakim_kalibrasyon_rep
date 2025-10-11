import { test } from "@playwright/test";

test("_setup - login ve storage state üret", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";
  await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded" });
  if (/\/login\//i.test(page.url())) {
    await page.fill('input[name="username"]', USER);
    await page.fill('input[name="password"]', PASS);
    await Promise.all([
      page.waitForLoadState("domcontentloaded"),
      page.locator('input[type="submit"], button[type="submit"]').first().click()
    ]);
  }
  await page.context().storageState({ path: "storage/user.json" });
});