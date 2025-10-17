import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("DEMO - Equipment List (DÜZELTİLMİŞ)", async ({ page }) => {
  console.log("🎬 DEMO TEST BAŞLADI (DÜZELTİLMİŞ)");
  
  // Admin'e git
  await page.goto('/admin/maintenance/equipment/');
  await page.waitForLoadState('networkidle');
  
  console.log("📍 Sayfa yüklendi, Add button aranıyor...");
  
  // DOĞRU SELECTOR! (Düzeltildi)
  const addButton = page.locator('a').filter({ hasText: /Add equipment|Ekle/i }).first();
  
  console.log("⏳ Add button bekleniyor...");
  await expect(addButton).toBeVisible({ timeout: 10000 });
  
  console.log("✅ Add button bulundu!");
  
  // Tıkla ve kontrol et
  await addButton.click();
  await page.waitForLoadState('networkidle');
  
  console.log("📍 Add sayfası açıldı");
  await expect(page).toHaveURL(/\/add\//);
  
  console.log("🎉 TEST BAŞARILI!");
});
