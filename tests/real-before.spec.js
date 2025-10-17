import { test, expect } from "@playwright/test";

test("🔴 BEFORE - Equipment 404 Error", async ({ page }) => {
  // Login
  await page.goto("http://127.0.0.1:8010/admin/login/");
  await page.fill("#id_username", "admin");
  await page.fill("#id_password", "admin");
  await page.click("input[type='submit']");
  await page.waitForLoadState('networkidle');
  
  console.log("🔴 BEFORE: Equipment sayfasına gitmeye çalışıyorum...");
  
  // 2 saniye admin panelini gör
  await page.waitForTimeout(2000);
  
  // Equipment ekleme sayfasına git
  await page.goto("http://127.0.0.1:8010/admin/maintenance/equipment/add/");
  
  // 3 saniye bekle - 404 HATASINI GÖR!
  await page.waitForTimeout(3000);
  
  // Sayfa başlığını kontrol et
  const title = await page.textContent("h1");
  console.log(`❌ Sayfa başlığı: ${title}`);
  
  // Form olmalı ama yok - 404 var
  await expect(page.locator("form")).toBeVisible({ timeout: 2000 });
});
