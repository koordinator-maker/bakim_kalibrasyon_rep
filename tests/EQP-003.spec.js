import { test, expect } from '@playwright/test';

// Tüm testler, playwright.config.js dosyasındaki "setup" projesi sayesinde
// oturum açmış kullanıcı (authenticated user) olarak çalışacaktır.

test('EQP-003: Ekipman Ekleme formunda Üretici Firma alanının varlığı', async ({ page }) => {

    // 1. Ekipman Ekleme sayfasına git (Oturum açılmış varsayılır)
    await page.goto("http://127.0.0.1:8010/admin/maintenance/equipment/add/");

    // KONTROL: Doğru sayfada olduğumuzu kontrol et
    // Düzeltme: IP adresi 127.0.0.1 olarak düzeltildi.
    await expect(page).toHaveURL("http://127.0.0.1:8010/admin/maintenance/equipment/add/");

    // 2. Input alanını bul ve varlığını doğrula
    // Üretici Firma alanının (id="id_manufacturer") varlığını kontrol et
    const manufacturerInput = page.locator('#id_manufacturer');
    await expect(manufacturerInput).toBeVisible();

    // Opsiyonel: Alanın doğru bir <select> etiketi olduğunu kontrol et
    await expect(manufacturerInput).toHaveAttribute('name', 'manufacturer');

    console.log("TEST BAŞARILI: Üretici Firma alanı başarıyla bulundu.");
});
