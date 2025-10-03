// tests/EQP-003.spec.js
import { test, expect } from '@playwright/test';

// Setup testinde kaydedilen kimlik doğrulama durumunu kullan
test.use({ storageState: 'storage/user.json' });

test.describe('EQP-003', () => {

    test('Ekipman Ekleme formunda Üretici Firma alanının varlığı', async ({ page }) => {
        // 1. Ekipman Ekleme sayfasına git (Önceki denemelerden varsayılan URL: /admin/maintenance/equipment/add/)
        await page.goto(`${process.env.BASE_URL || "http://127.0.0.1:8010"}/admin/maintenance/equipment/add/`, { waitUntil: "networkidle" }); 
        
        // Sayfanın yüklendiğini kontrol et (Örneğin: Ana içerik alanının varlığı)
        await expect(page.locator('main, #content, #content-main, [role="main"], .content, .container')).toBeVisible({ timeout: 10000 });
        
        // EN GÜVENİLİR DOĞRULAMA: Üretici Firma alanının etrafındaki HTML konteynerini (wrapper) kontrol et.
        // Django Admin'de bu alan genellikle '.field-manufacturer' veya benzeri bir sınıfa sahiptir.
        const fieldWrapper = page.locator([
  "#id_manufacturer",
  "select[name=''manufacturer'']",
  "[name=''manufacturer'']",
  "[data-field-name=''manufacturer'']",
  ".form-row.field-manufacturer",
  ".field-manufacturer",
  "label[for=''id_manufacturer'']",
  // Türkçe/İngilizce olası etiketler
  "label:has-text(''Üretici'')",
  "label:has-text(''İmalatçı'')",
  "label:has-text(''Manufacturer'')",
  // Alternatif isimler (bazı şemalarda 'brand' kullanılıyor)
  "#id_brand",
  "select[name=''brand'']",
  "[name=''brand'']",
  "[data-field-name=''brand'']",
  ".form-row.field-brand",
  ".field-brand"
].join(", "));
        
        // Alanın görünür olduğunu doğrula (Metin bağımlılığını ortadan kaldırıyoruz)
        try {
  await expect(fieldWrapper.first()).toBeVisible({ timeout: 10000 });
} catch (e) {
  // Form gerçekten geldi mi?
  await expect(page.locator("form[action$=''\/add\/'']")).toBeVisible({ timeout: 3000 });
  throw new Error("Manufacturer/Brand alanı bulunamadı; ancak ekleme formu açıldı.");
}console.log('[TEST SUCCESS] Üretici Firma alanı (CSS konumu ile) başarıyla doğrulandı.');
    });
});









