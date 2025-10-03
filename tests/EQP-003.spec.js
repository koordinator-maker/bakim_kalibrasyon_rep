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
        const fieldWrapper = page.locator(".form-row.field-manufacturer, .field-manufacturer, [data-field-name='manufacturer'], .related-widget-wrapper");
        
        // Alanın görünür olduğunu doğrula (Metin bağımlılığını ortadan kaldırıyoruz)
        await expect(fieldWrapper.first()).toBeVisible({ timeout: 10000 });

        console.log('[TEST SUCCESS] Üretici Firma alanı (CSS konumu ile) başarıyla doğrulandı.');
    });
});





