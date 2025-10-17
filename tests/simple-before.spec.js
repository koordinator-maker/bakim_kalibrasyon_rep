import { test, expect } from "@playwright/test";

test("🔴 BEFORE - Login FAIL", async ({ page }) => {
  // Admin login sayfasına git
  await page.goto("http://127.0.0.1:8010/admin/login/");
  
  console.log("🔴 Login sayfası - YANLIŞ şifre deneniyor...");
  
  // 2 saniye bekle - sayfayı gör
  await page.waitForTimeout(2000);
  
  // YANLIŞ giriş
  await page.fill("#id_username", "wrong");
  await page.fill("#id_password", "wrong");
  
  // 1 saniye bekle - form doldurulmuş halini gör
  await page.waitForTimeout(1000);
  
  // Login'e tıkla
  await page.click("input[type='submit']");
  
  // 3 saniye bekle - HATA MESAJINI GÖR
  await page.waitForTimeout(3000);
  
  console.log("❌ Hata mesajı görünüyor - başarısız login!");
  
  // Bu başarısız olacak - hata var çünkü
  await expect(page.locator("#user-tools")).toBeVisible({ timeout: 1000 });
});
