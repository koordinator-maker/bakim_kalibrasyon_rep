import { test, expect } from "@playwright/test";

test("admin anasayfa erişim", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  // Auto-login
  await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded" });
  if (/\/admin\/login\//.test(page.url())) {
    await page.fill("#id_username", USER);
    await page.fill("#id_password", PASS);
    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded" }),
      page.locator('input[type="submit"],button[type="submit"]').first().click(),
    ]);
  }

  // Admin index doğrulaması
  await expect(page).toHaveURL(new RegExp("/admin/?$"));
  const bodyText = await page.textContent("body").catch(()=> "");
  expect(bodyText || "").toMatch(/Django administration|Site administration/i);
});