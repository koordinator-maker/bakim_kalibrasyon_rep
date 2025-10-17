import { test, expect } from "@playwright/test";

test("✅ AFTER - Login SUCCESS", async ({ page }) => {
  // Admin login sayfasına git
  await page.goto("http://127.0.0.1:8010/admin/login/");
  
  console.log("✅ Login sayfası - DOĞRU şifre deneniyor...");
  
  // 2 saniye bekle - sayfayı gör
  await page.waitForTimeout(2000);
  
  // DOĞRU giriş
  await page.fill("#id_username", "admin");
  await page.fill("#id_password", "admin");
  
  // 1 saniye bekle - form doldurulmuş halini gör
  await page.waitForTimeout(1000);
  
  // Login'e tıkla
  await page.click("input[type='submit']");
  
  // 3 saniye bekle - ADMIN PANELİNİ GÖR
  await page.waitForTimeout(3000);
  
  console.log("✅ Admin paneli açıldı - başarılı login!");
  
  // Başarılı - admin panelindeyiz
  await expect(page.locator("#user-tools")).toBeVisible();
  
  // 2 saniye daha - yeşil ekranı gör
  await page.waitForTimeout(2000);
});
