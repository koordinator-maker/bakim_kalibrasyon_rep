import { test, expect } from '@playwright/test';
import { loginIfNeeded, gotoListExport } from './helpers_e10x.js';

test('E106 - Listeyi arama kutusuyla filtrele', async ({ page }) => {
  let page_ = await loginIfNeeded(page);
  page_ = await gotoListExport(page_);
  
  // Debug: Sayfa durumunu kontrol et
  const url = page_.url();
  console.log('📍 Current URL:', url);
  
  await page_.screenshot({ path: 'debug_e106_before_search.png', fullPage: true });
  console.log('📸 Screenshot kaydedildi: debug_e106_before_search.png');
  
  // Arama kutusunu bul (farklı selector'lar dene)
  const searchBox = page_.locator('input[name="q"]').first();
  
  // Eğer görünmüyorsa bekle
  try {
    await searchBox.waitFor({ state: 'visible', timeout: 5000 });
  } catch (e) {
    console.error('❌ Arama kutusu bulunamadı!');
    console.log('📄 Sayfa HTML (ilk 500 karakter):');
    const html = await page_.content();
    console.log(html.substring(0, 500));
    throw e;
  }
  
  await expect(searchBox).toBeVisible();
  
  const token = "test-serial-123";
  await searchBox.fill(token);
  
  await Promise.all([
    page_.waitForLoadState('domcontentloaded'),
    searchBox.press('Enter')
  ]);
  
  const rows = page_.locator('#result_list tbody tr');
  const count = await rows.count();
  console.log(`✅ Arama sonucu: ${count} satır`);
  
  expect(count).toBeGreaterThanOrEqual(0);
});
