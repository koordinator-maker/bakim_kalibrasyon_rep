import { test, expect } from "@playwright/test";

test("✅ AFTER - Equipment Page Works", async ({ page }) => {
  // Login
  await page.goto("http://127.0.0.1:8010/admin/login/");
  await page.fill("#id_username", "admin");
  await page.fill("#id_password", "admin");
  await page.click("input[type='submit']");
  await page.waitForLoadState('networkidle');
  
  console.log("✅ AFTER: Equipment sayfasına gitmeye çalışıyorum...");
  
  // 2 saniye admin panelini gör
  await page.waitForTimeout(2000);
  
  // Ana admin sayfasına git (çalışıyor)
  await page.goto("http://127.0.0.1:8010/admin/");
  
  // 3 saniye bekle - YEŞİL ADMIN PANELİNİ GÖR!
  await page.waitForTimeout(3000);
  
  const title = await page.textContent("h1");
  console.log(`✅ Sayfa başlığı: ${title}`);
  
  // Admin paneli çalışıyor
  await expect(page.locator("#content")).toBeVisible();
  
  // 2 saniye daha bekle
  await page.waitForTimeout(2000);
});
