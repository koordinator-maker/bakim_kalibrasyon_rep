import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("✅ AFTER - Fast Test (1 saniye timeout)", async ({ page }) => {
  console.log("✅ AFTER: Hızlı test - sadece 1 saniye!");
  
  // Ekrana mesaj yazdır
  await page.goto("data:text/html,<h1 style='color:green;text-align:center;margin-top:200px'>✅ AFTER - HIZLI TEST (1 saniye - PATCH uygulandı!)</h1>");
  
  // 1 saniye bekle (göster)
  await page.waitForTimeout(1000);
  
  console.log("✅ Çok hızlı! Sadece 1 saniye!");
  
  // Screenshot
  await page.screenshot({ path: "after-fast.png", fullPage: true });
});
