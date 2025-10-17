import { test, expect } from "@playwright/test";

// Global setup'ı devre dışı bırak - temiz session
test.use({ storageState: undefined });

test.setTimeout(60000);

test("🔴 BEFORE - Wrong Login", async ({ page }) => {
  console.log("🔴 BEFORE: Yanlış şifre ile login...");
  
  await page.goto("http://127.0.0.1:8010/admin/login/");
  
  // Sayfanın yüklendiğini gör
  await page.waitForTimeout(2000);
  
  // YANLIŞ credentials
  await page.locator("#id_username").fill("wrong_user");
  await page.locator("#id_password").fill("wrong_password");
  
  // Girişi gör
  await page.waitForTimeout(1000);
  
  // Submit
  await page.locator("input[type='submit']").click();
  
  // Hata mesajını gör (3 saniye)
  await page.waitForTimeout(3000);
  
  // HATA mesajı var mı kontrol et
  const hasError = await page.locator(".errornote").isVisible();
  console.log(`❌ Error visible: ${hasError}`);
  
  // Test başarısız olacak - admin panelinde değiliz
  await expect(page.locator("#user-tools")).toBeVisible({ timeout: 2000 });
});
