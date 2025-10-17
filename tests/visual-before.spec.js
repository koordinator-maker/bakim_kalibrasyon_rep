import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("🔴 BEFORE - Slow Test (5 saniye timeout)", async ({ page }) => {
  console.log("🔴 BEFORE: Yavaş test - 5 saniye bekleme...");
  
  // Ekrana mesaj yazdır
  await page.goto("data:text/html,<h1 style='color:red;text-align:center;margin-top:200px'>🔴 BEFORE - YAVAŞ TEST (5 saniye bekliyor...)</h1>");
  
  // 5 saniye bekle (göster)
  await page.waitForTimeout(5000);
  
  console.log("❌ Çok yavaş! 5 saniye bekledi!");
  
  // Screenshot
  await page.screenshot({ path: "before-slow.png", fullPage: true });
});
