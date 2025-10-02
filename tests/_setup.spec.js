// tests/_setup.spec.js
import { test as setup, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

const authFile = path.join(process.cwd(), 'storage', 'user.json');

// Login attempt function (Uses URL redirection check)
async function attemptLogin(page, username, password) {
    console.log(`[LOGIN] Attempting to log in with: ${username} / ${password.slice(0, 4)}****`);
    
    // 1. Go to the login page
    await page.goto("/admin/login/", { waitUntil: "domcontentloaded" }); 

    // 2. Fill username and password
    await page.locator('input[name="username"]').fill(username);
    await page.locator('input[name="password"]').fill(password); 

    // 3. Click the login button and wait for the successful URL (/admin/) or stay on the login page.
    await page.locator('input[type="submit"]').click();
    
    try {
        // Wait for the URL to change AND network activity to cease (networkidle)
        await page.waitForURL(url => url.pathname.startsWith('/admin/') && !url.pathname.includes('/admin/login/'), { 
            waitUntil: 'networkidle', // Sayfanın tamamen yüklendiğinden emin olmak için en güçlü bekleme
            timeout: 45000 // Toplam bekleme süresi 45 saniyeye çıkarıldı.
        });

        // NIHAI VE KESIN DOGRULAMA: Login formunun (kullanıcı adı giriş kutusunun) artık sayfada görünür OLMADIĞINI kontrol et.
        const loginFormUsernameInput = page.locator('input[name="username"]');
        await expect(loginFormUsernameInput).not.toBeVisible({ timeout: 10000 }); 
        
        console.log('[LOGIN SUCCESS] Login attempt succeeded and login form is gone.');
        return true;

    } catch (e) {
        // ... (Error handling remains the same)
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
    
    // KULLANILAN KIMLIK BILGILERI: hp2 / Asla1234
    const USERNAME = 'hp2';
    const PASSWORD = 'Asla1234';
    
    await attemptLogin(page, USERNAME, PASSWORD);

    // 5. Save the session state (Only if login was successful)
    const authFile = path.join(process.cwd(), 'storage', 'user.json');
    await page.context().storageState({ path: authFile });
    
    if (fs.existsSync(authFile)) {
        console.log(`[SETUP SUCCESS] Session state successfully saved to: ${authFile}`);
    } else {
        throw new Error(`[SETUP FAILURE] Failed to save session state: ${authFile}`);
    }
});
