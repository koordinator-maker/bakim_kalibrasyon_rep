import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("VISUAL TEST - Selector error", async ({ page }) => {
  console.log("🔴 BEFORE PATCH - Testing with WRONG selector...");
  
  await page.goto("http://127.0.0.1:8010/admin/");
  
  // HATA: Olmayan selector (3 saniye bekle, görsel olarak gör)
  await page.waitForTimeout(3000);
  
  try {
    await page.locator("#wrong-selector-xyz-123").click({ timeout: 5000 });
  } catch (e) {
    console.log("❌ ERROR: Selector not found (EXPECTED)");
    throw e;
  }
});
