import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("ERROR-TEST - Fixed by Claude", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/");
  
  // ✅ CLAUDE FIX: Doğru selector kullan
  await page.locator("#user-tools").waitFor({ timeout: 10000 });
  
  await expect(page).toHaveURL(/\/admin/);
});
