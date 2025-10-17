import { test, expect } from "@playwright/test";

// Global setup'ı devre dışı bırak - temiz session
test.use({ storageState: undefined });

test.setTimeout(60000);

test("✅ AFTER - Correct Login", async ({ page }) => {
  console.log("✅ AFTER: Doğru şifre ile login...");
  
  await page.goto("http://127.0.0.1:8010/admin/login/");
  
  // Sayfanın yüklendiğini gör
  await page.waitForTimeout(2000);
  
  // DOĞRU credentials
  await page.locator("#id_username").fill("admin");
  await page.locator("#id_password").fill("admin");
  
  // Girişi gör
  await page.waitForTimeout(1000);
  
  // Submit
  await page.locator("input[type='submit']").click();
  
  // Başarılı girişi gör (3 saniye)
  await page.waitForTimeout(3000);
  
  // Admin panelindeyiz!
  await expect(page.locator("#user-tools")).toBeVisible();
  console.log("✅ SUCCESS: Admin paneline girildi!");
  
  // URL kontrolü
  await expect(page).toHaveURL(/\/admin\//);
  
  // Biraz daha bekle (görmek için)
  await page.waitForTimeout(2000);
});
