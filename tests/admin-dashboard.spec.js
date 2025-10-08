import { test, expect } from "@playwright/test";

test.describe("Admin Dashboard Tests", () => {
  test("should access admin panel", async ({ page, baseURL }) => {
    const res = await page.goto(`${baseURL}/admin/`, { waitUntil: "domcontentloaded" });
    expect(res?.status()).toBeLessThan(400);
    await expect(page.locator("#branding h1, #site-name a")).toBeVisible({ timeout: 7000 });
    await expect(page.locator("#content, .dashboard, .app-index")).toBeVisible({ timeout: 7000 });
  });

  test("should list users in admin", async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/admin/`, { waitUntil: "domcontentloaded" });
    const userLink = page.getByRole("link", { name: /users|kullanÃ„Â±cÃ„Â±/iu }).first()
      .or(page.locator('a[href*="/auth/user/"], a[href*="/accounts/"][href*="user"]')).first();
    await userLink.click();
    await expect(page.locator("table#result_list")).toBeVisible({ timeout: 8000 });
  });
});