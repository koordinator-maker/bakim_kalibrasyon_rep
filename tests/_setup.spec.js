// tests/_setup.spec.js
import { test as setup, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

const authFile = path.join(process.cwd(), 'storage', 'user.json');

// Login attempt function (Uses Promise.race for immediate success/failure detection)
async function attemptLogin(page, username, password) {
    console.log(`[LOGIN] Attempting to log in with: ${username} / ${password.slice(0, 1)}****`);
    
    // 1. Go to the login page
    await page.goto("/admin/login/", { waitUntil: "domcontentloaded" }); 

    // 2. Fill username and password
    await page.locator('input[name="username"]').fill(username);
    await page.locator('input[name="password"]').fill(password); 

    // 3. Click the login button
    await page.locator('input[type="submit"]').click();

    // Locators for success (Logout link) and failure (Error note)
    const logoutLink = page.locator('#user-tools a:has-text("Çıkış")');
    const errorNote = page.locator('.errornote');

    // 4. Race: Wait for success or failure to appear first (10 seconds timeout for race).
    const raceTimeout = 10000; 

    const successPromise = logoutLink.waitFor({ state: 'visible', timeout: raceTimeout }).then(() => 'success');
    const failurePromise = errorNote.waitFor({ state: 'visible', timeout: raceTimeout }).then(() => 'failure');

    const result = await Promise.race([successPromise, failurePromise]);
    
    if (result === 'failure') {
        const errorMessage = await errorNote.innerText();
        throw new Error(errorMessage); // Throw the Django Error Message
    }
    
    if (result === 'success') {
        console.log('[LOGIN SUCCESS] Login attempt succeeded.');
        return true; // Successful login
    }

    // Fallback error for unexpected case
    throw new Error('Login process timed out or an unexpected state occurred after clicking submit.');
}

setup('login state create and save to storage/user.json', async ({ page }) => {
    
    try {
        // 1. Primary attempt: admin / A1234
        await attemptLogin(page, 'admin', 'A1234');
        
    } catch (e) {
        // Check for common English/Turkish Django login failure messages
        const isLoginError = e.message.includes('correct username and password') || 
                             e.message.includes('Lütfen doğru kullanıcı adı');
        
        if (isLoginError) {
            console.warn(`[WARNING] First attempt (admin/A1234) failed. Error: "${e.message.split('\n')[0]}".`);
            
            // 2. Secondary attempt: hp / A1234
            try {
                 await attemptLogin(page, 'hp', 'A1234');
            } catch (e2) {
                // Check if the second attempt also failed due to incorrect credentials
                const isSecondLoginError = e2.message.includes('correct username and password') || 
                                           e2.message.includes('Lütfen doğru kullanıcı adı');
                
                if (isSecondLoginError) {
                    throw new Error(`CRITICAL ERROR: Both login attempts (admin/A1234 and hp/A1234) failed. Please CHECK your Django admin user passwords.`);
                }
                throw e2; // Throw unexpected second attempt error
            }

        } else {
            // Throw the original non-login error (like a network timeout, not a credential failure)
            throw e; 
        }
    }
    
    // 5. Save the session state (Only if login was successful in step 1 or 2)
    await page.context().storageState({ path: authFile });
    
    if (fs.existsSync(authFile)) {
        console.log(`[SETUP SUCCESS] Session state successfully saved to: ${authFile}`);
    } else {
        throw new Error(`[SETUP FAILURE] Failed to save session state: ${authFile}`);
    }
});
