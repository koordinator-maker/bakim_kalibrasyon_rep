// tests/_setup.spec.js
import { test as setup } from '@playwright/test';
import path from 'path';
import fs from 'fs';

// Oturum durumunun kaydedileceği kesin yolu tanımlama (root/storage/user.json)
const authFile = path.join(process.cwd(), 'storage', 'user.json');

setup('login state üret ve storage/user.json kaydet', async ({ page }) => {
    // 1. Django Admin Login sayfasına git (baseURL otomatik eklenecek)
    await page.goto("/admin/login/", { waitUntil: "domcontentloaded" }); 

    // 2. Kullanıcı adı ve şifreyi gir (Admin/Admin123 varsayımı)
    await page.getByLabel('Kullanıcı adı').fill('admin'); 
    await page.getByLabel('Şifre').fill('admin123'); 

    // 3. Giriş yap butonuna tıkla
    await page.locator('input[type="submit"]').click();

    // 4. Admin ana sayfasına yönlendirildiğini kontrol et
    await page.waitForURL('/admin/', { waitUntil: 'domcontentloaded' });

    // 5. Oturum durumunu kaydet
    await page.context().storageState({ path: authFile });
    
    // Oturum dosyası kaydedildiğinde emin olmak için konsol çıktısı
    if (fs.existsSync(authFile)) {
        console.log(`[SETUP SUCCESS] Oturum durumu başarıyla şuraya kaydedildi: ${authFile}`);
    } else {
        console.error(`[SETUP FAILURE] Oturum durumu kaydedilemedi: ${authFile}`);
    }
});
