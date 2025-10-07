// Dosya: example.spec.js
// Bu dosya, Playwright'ın doğru çalıştığını ve raporlayıcıyı tetiklediğini doğrulamak için eklenmiştir.

const { test, expect } = require('@playwright/test');

test('example basic test', async ({ page }) => {
  // Basit bir sayfaya gitmeyi dener
  await page.goto('https://playwright.dev/');
  
  // Başlıkta 'Playwright' kelimesinin geçtiğini doğrular
  await expect(page).toHaveTitle(/Playwright/);
  
  // 'Get started' bağlantısını bulur ve tıklar
  await page.getByRole('link', { name: 'Get started' }).click();
  
  // URL'nin /docs/intro ile bittiğini doğrular (navigasyon başarılı)
  await expect(page).toHaveURL(/.*intro/);
});
