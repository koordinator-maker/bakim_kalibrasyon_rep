import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("✅ AFTER - Login SUCCESS", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/login/");
  
  console.log("✅ AFTER PATCH: Doğru credentials ile login yapın...");
  
  // DOĞRU credentials
  await page.locator("#id_username").fill("admin");
  await page.locator("#id_password").fill("admin");
  
  // 2 saniye bekle (görmek için)
  await page.waitForTimeout(2000);
  
  // Login butonuna tıkla
  await page.locator("input[type='submit']").click();
  
  // 3 saniye bekle (başarılı girişi gör)
  await page.waitForTimeout(3000);
  
  // Başarılı - admin panelindeyiz!
  await expect(page.locator("#user-tools")).toBeVisible();
  console.log("✅ SUCCESS: Admin paneline giriş yapıldı!");
  
  // Admin panelinde olduğumuzu doğrula
  await expect(page).toHaveURL(/\/admin\//);
  
  // 2 saniye daha bekle (başarılı ekranı gör)
  await page.waitForTimeout(2000);
});
