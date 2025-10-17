import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("ERROR-TEST - Yanlış selector", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/");
  
  // KASITLI HATA: Olmayan selector
  await page.locator("#nonexistent-button-xyz").click();
  
  await expect(page).toHaveURL(/\/admin\/maintenance/);
});
