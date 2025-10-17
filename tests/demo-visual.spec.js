import { test, expect } from "@playwright/test";

test("🔴 BEFORE - Wrong Selector", async ({ page }) => {
  console.log("🔴 TESTING WITH WRONG SELECTOR...");
  
  await page.goto("http://127.0.0.1:8010/admin/");
  await page.waitForTimeout(5000);
  
  console.log("Trying to click non-existent element...");
  await page.locator("#WRONG-SELECTOR-XYZ").click({ timeout: 5000 });
});
