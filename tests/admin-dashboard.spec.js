import { test, expect } from "@playwright/test";

test.describe("Admin Dashboard Tests", () => {
  test("should access admin panel", async ({ page }) => {
    await page.goto("/admin/");
    await expect(page.getByText("Django administration")).toBeVisible();
  });

  test("should list users in admin", async ({ page }) => {
    await page.goto("/admin/");
    // Users link: /auth/user/ veya /accounts/...user...
    const userLink = page.locator('a[href*="/auth/user/"], a[href*="/accounts/"][href*="user"]').first();
    await userLink.click({ timeout: 10000 });
    await expect(page.locator("table#result_list")).toBeVisible({ timeout: 8000 });
  });
});