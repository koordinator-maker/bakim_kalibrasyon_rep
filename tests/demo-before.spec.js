import { test, expect } from "@playwright/test";

test.setTimeout(60000);

test("🔴 BEFORE - Login FAILED", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/login/");
  
  console.log("🔴 BEFORE PATCH: Yanlış credentials ile login deneyin...");
  
  // Formu doldur
  await page.locator("#id_username").fill("wrong_user");
  await page.locator("#id_password").fill("wrong_password");
  
  // 2 saniye bekle (görmek için)
  await page.waitForTimeout(2000);
  
  // Login butonuna tıkla
  await page.locator("input[type='submit']").click();
  
  // 3 saniye bekle (hata mesajını gör)
  await page.waitForTimeout(3000);
  
  // Hata bekliyoruz - admin paneline GİREMEYECEK
  const errorMsg = await page.locator(".errornote").textContent();
  console.log(`❌ ERROR: ${errorMsg}`);
  
  // Bu başarısız olacak - admin panelinde değiliz
  await expect(page.locator("#user-tools")).toBeVisible({ timeout: 2000 });
});
