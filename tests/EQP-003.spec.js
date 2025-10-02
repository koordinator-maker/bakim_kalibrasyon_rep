import { test, expect } from "@playwright/test";

test("EQP-003: Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
    // 1. Django Admin Login sayfasına git
    await page.goto("http://127.0.0.1:8010/admin/");

    // 2. Oturum aç
    await page.fill("#id_username", "admin");
    await page.fill("#id_password", "admin");
    await page.click("text=Log in");

    // 3. Yeni Ekipman Ekleme sayfasına git
    await page.goto("http://127.0.0.1:8010/admin/maintenance/equipment/add/");
    
    // 4. Input alanını ID ile bul. admin.py değişikliği sonrası bu artık orada olmalı.
    const manufacturerInput = page.locator('#id_manufacturer');
    
    // İlgili input alanının göründüğünü doğrula
    await expect(manufacturerInput).toBeVisible();

    console.log("✅ EQP-003: 'Üretici Firma' input alanı başarıyla doğrulandı.");
});
