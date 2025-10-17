import { test, expect } from "@playwright/test";

test.setTimeout(90000);

test("LIVE TEST - Equipment Listeleme", async ({ page }) => {
  console.log("🎬 TEST BAŞLADI!");
  
  // 1. Adım: Admin panele git
  console.log("📍 ADIM 1: Admin panele gidiliyor...");
  await page.goto('/admin/');
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(3000); // 3 saniye bekle
  
  // 2. Adım: Maintenance'a tıkla
  console.log("📍 ADIM 2: Maintenance menüsüne tıklanıyor...");
  const maintenanceLink = page.locator('a').filter({ hasText: /Maintenance|MAINTENANCE/i }).first();
  
  if (await maintenanceLink.count() > 0) {
    await maintenanceLink.click();
    await page.waitForTimeout(3000); // 3 saniye bekle
  }
  
  // 3. Adım: Equipment'e git
  console.log("📍 ADIM 3: Equipment sayfasına gidiliyor...");
  await page.goto('/admin/maintenance/equipment/');
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(3000); // 3 saniye bekle
  
  // 4. Adım: Sayfa kontrol
  console.log("📍 ADIM 4: Sayfa kontrol ediliyor...");
  
  const is404 = await page.locator('h1').filter({ hasText: /404|Not Found/i }).count() > 0;
  
  if (is404) {
    console.log("❌ 404 - Equipment admin'e kayıtlı değil!");
    throw new Error("404 - Equipment not registered in admin");
  }
  
  console.log("✅ Equipment sayfası açıldı!");
  
  // 5. Adım: Add button kontrol
  console.log("📍 ADIM 5: Add button kontrol ediliyor...");
  const addButton = page.locator('a').filter({ hasText: /Add|Ekle/i }).first();
  await expect(addButton).toBeVisible({ timeout: 5000 });
  await page.waitForTimeout(3000); // 3 saniye bekle
  
  console.log("🎉 TEST BAŞARILI!");
});
