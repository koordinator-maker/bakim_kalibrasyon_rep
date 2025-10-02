// tests/_setup.spec.js
import { test as setup, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

const authFile = path.join(process.cwd(), 'storage', 'user.json');

// Login attempt function (Uses URL redirection check)
async function attemptLogin(page, username, password) {
    console.log(`[LOGIN] Attempting to log in with: ${username} / ${password.slice(0, 4)}****`);
    
    // 1. Go to the login page - KRİTİK: localhost kullanarak tam URL ile deniyoruz
    try {
        await page.goto("http://localhost:8000/admin/login/", {
            waitUntil: "networkidle",
            timeout: 30000 
        });
        
        // **YENİ KRİTİK ADIM:** Sayfanın başlığının "Log in" veya benzeri bir metin içerdiğini kontrol et.
        // Bu, sayfanın HTML'inin gerçekten yüklendiğini garanti eder.
        await expect(page).toHaveTitle(/Log in|Site administration/i, { timeout: 10000 });
        console.log('[LOGIN] Sayfa basligi basarili sekilde dogrulandi.');

    } catch (e) {
        throw new Error(`[CRITICAL CONNECTION ERROR] Login sayfasina ulasilamadi veya dogru yuklenmedi (http://localhost:8000/admin/login/). Sunucunuzun calistigini ve adresin dogru oldugunu kontrol edin. Hata: ${e.message}`);
    }

    const usernameInput = page.locator('input[name="username"]');

    // 2. Fill username and password.
    // Sayfa baslik kontrolunden gectigi icin, bu adim artik basarili olmali.
    await usernameInput.fill(username);
    await page.locator('input[name="password"]').fill(password); 

    // 3. Click the login button and wait for the successful URL
    await page.locator('input[type="submit"]').click();
    
    // ... (Kalan basarili dogrulama adimlari ayni kaliyor)
    try {
        await page.waitForURL(url => url.pathname.startsWith('/admin/') && !url.pathname.includes('/admin/login/'), { 
            waitUntil: 'networkidle', 
            timeout: 30000 
        });

        const loginFormUsernameInput = page.locator('input[name="username"]');
        await expect(loginFormUsernameInput).not.toBeVisible({ timeout: 5000 }); 
        
        console.log('[LOGIN SUCCESS] Login attempt succeeded and login form is gone.');
        return true;

    } catch (e) {
        const currentUrl = page.url();

        if (currentUrl.includes('/admin/login/')) {
            const errorNote = page.locator('.errornote');
            if (await errorNote.isVisible({ timeout: 5000 })) {
                 const errorMessage = await errorNote.innerText();
                 if (errorMessage.includes('username and password')) {
                      throw new Error(`[CRITICAL CREDENTIAL ERROR] Login Failed. Django Error Mesaji: "${errorMessage}". Lutfen 'hp2' / 'Asla1234' kombinasyonunun aktifliğini kontrol edin.`);
                 }
                 throw new Error(errorMessage);
            }
        }
        
        throw e;
    }
}

setup('login state create and save to storage/user.json', async ({ page }) => {
    
    const USERNAME = 'hp2';
    const PASSWORD = 'Asla1234';
    
    await attemptLogin(page, USERNAME, PASSWORD);

    const authFile = path.join(process.cwd(), 'storage', 'user.json');
    await page.context().storageState({ path: authFile });
    
    if (fs.existsSync(authFile)) {
        console.log(`[SETUP SUCCESS] Session state successfully saved to: ${authFile}`);
    } else {
        throw new Error(`[SETUP FAILURE] Failed to save session state: ${authFile}`);
    }
});
