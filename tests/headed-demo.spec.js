import { test, expect } from "@playwright/test";

test("Equipment - Pencere Açık Test", async ({ page }) => {
  console.log("\n🎬 TEST BAŞLADI - PENCERE AÇIK!\n");
  
  // Admin'e git
  console.log("📍 1. Admin panele gidiliyor...");
  await page.goto('/admin/');
  await page.waitForTimeout(3000);
  console.log("   ✅ Admin açıldı (3sn beklendi)\n");
  
  // Equipment sayfası
  console.log("📍 2. Equipment sayfasına gidiliyor...");
  await page.goto('/admin/maintenance/equipment/');
  await page.waitForTimeout(3000);
  console.log("   ✅ Equipment açıldı (3sn beklendi)\n");
  
  // 404 kontrolü
  const is404 = await page.locator('h1').filter({ hasText: /404|Not Found/i }).count() > 0;
  
  if (is404) {
    console.log("❌ 404 HATA - Equipment admin'e kayıtlı değil!\n");
    await page.waitForTimeout(3000);
    throw new Error("404 - Equipment not found");
  }
  
  console.log("✅ Equipment sayfası OK!\n");
  await page.waitForTimeout(3000);
  
  console.log("🎉 TEST BAŞARILI!\n");
});
