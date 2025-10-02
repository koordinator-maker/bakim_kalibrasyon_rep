// tests/_setup.spec.js
import { test as setup, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

const authFile = path.join(process.cwd(), 'storage', 'user.json');
const MAX_LOGIN_TIMEOUT = 30000; // Total maximum time to wait for login actions

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
        // Wait for the URL to change to the successful admin page (e.g., /admin/)
        await page.waitForURL(url => url.pathname.startsWith('/admin/') && !url.pathname.includes('/admin/login/'), { 
            timeout: MAX_LOGIN_TIMEOUT 
        });

        // SUCCESS: Final quick check for the standard logout link once the URL changes
        const logoutLink = page.locator('#user-tools a:has-text("Çıkış")');
        await expect(logoutLink).toBeVisible({ timeout: 5000 }); 
        
        console.log('[LOGIN SUCCESS] Login attempt succeeded and URL redirected.');
        return true;

    } catch (e) {
        // If the URL didn't change (still on login page or timed out), check for the explicit error note
        const currentUrl = page.url();

        if (currentUrl.includes('/admin/login/')) {
            const errorNote = page.locator('.errornote');
            if (await errorNote.isVisible({ timeout: 5000 })) {
                 const errorMessage = await errorNote.innerText();
                 // If the error note confirms incorrect credentials, re-throw with a clean message
                 if (errorMessage.includes('username and password')) {
                      throw new Error(`[CRITICAL CREDENTIAL ERROR] Login Failed. Django Hata Mesaji: "${errorMessage}". Lutfen 'hp1' / 'Asla1234' kombinasyonunu kontrol edin.`);
                 }
                 throw new Error(errorMessage); // Throw any other Django error
            }
        }
        
        // If not successful, not a login page error, throw the original error (e.g., timeout)
        throw e;
    }
}

setup('login state create and save to storage/user.json', async ({ page }) => {
    
    // DOGRU KIMLIK BILGILERI KULLANILIYOR: hp1 / Asla1234
    const USERNAME = 'hp1';
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
