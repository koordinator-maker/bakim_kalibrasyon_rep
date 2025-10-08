const fs = require("fs");
const path = require("path");
const { chromium } = require("@playwright/test");

module.exports = async () => {
  const baseURL  = process.env.BASE_URL   || "http://127.0.0.1:8010";
  const username = process.env.ADMIN_USER || "admin";
  const password = process.env.ADMIN_PASS || "admin";
  const storage  = path.resolve("storage","user.json");

  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext();
  const page = await ctx.newPage();

  try {
    // Admin'e git
    await page.goto(`${baseURL}/admin/`, { waitUntil: "domcontentloaded", timeout: 60000 });

    // Login formu var mÄ±?
    const hasUser = await page.locator("#id_username, input[name='username']").first().isVisible().catch(() => false);
    const hasPass = await page.locator("#id_password, input[name='password']").first().isVisible().catch(() => false);

    if (hasUser && hasPass) {
      await page.fill("#id_username, input[name='username']", username);
      await page.fill("#id_password, input[name='password']", password);

      // GÃ¶nder: Ã¶nce submit butonu, yoksa Enter
      const submitBtn = page.locator("button[type='submit'], input[type='submit'], text=/Log in|GiriÅŸ|Oturum AÃ§/i").first();
      if (await submitBtn.isVisible().catch(() => false)) {
        await Promise.all([
          page.waitForLoadState("networkidle", { timeout: 30000 }).catch(()=>null),
          submitBtn.click({ timeout: 15000 }).catch(()=>null),
        ]);
      } else {
        await page.keyboard.press("Enter");
        await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(()=>null);
      }

      // BaÅŸarÄ± sinyallerinden herhangi birine bekle
      await Promise.race([
        page.waitForURL(/\/admin(\/)?($|\?)/, { timeout: 20000 }).catch(() => null),
        page.waitForSelector("#content, .dashboard, .app-index, #user-tools a[href*='logout']", { timeout: 20000 }).catch(() => null),
      ]);
    } else {
      // Zaten login'li olabilir; yine de dashboard sinyallerine bak
      await Promise.race([
        page.waitForURL(/\/admin(\/)?($|\?)/, { timeout: 10000 }).catch(() => null),
        page.waitForSelector("#content, .dashboard, .app-index, #user-tools a[href*='logout']", { timeout: 10000 }).catch(() => null),
      ]);
    }
  } finally {
    // Her durumda storage yaz (en azÄ±ndan dosya oluÅŸsun)
    fs.mkdirSync(path.dirname(storage), { recursive: true });
    await ctx.storageState({ path: storage });
    await browser.close();
    console.log(`[globalSetup] storage written â†’ ${storage}`);
  }
};

if (require.main === module) {
  (async () => {
    try {
      const fn = module.exports;
      if (typeof fn === 'function') {
        await fn();
      } else {
        console.error('[globalSetup] exported value is not a function');
        process.exit(1);
      }
    } catch (e) {
      console.error('[globalSetup] direct-run failed:', e && e.message ? e.message : e);
      process.exit(1);
    }
  })();
}