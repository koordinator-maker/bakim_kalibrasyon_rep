import { test, expect } from "@playwright/test";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("login check", async ({ page }) => {
  await page.context().clearCookies();
  await page.goto(`${BASE}/admin/login/`, { waitUntil: "domcontentloaded" });

  await page.fill("#id_username", process.env.ADMIN_USER || "admin");
  await page.fill("#id_password", process.env.ADMIN_PASS || "admin");

  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.locator('input[type="submit"], button[type="submit"]').first().click()
  ]);

  await expect(page).not.toHaveURL(/\/admin\/login\//);
});