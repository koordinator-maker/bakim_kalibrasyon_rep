const fs = require("fs");
const path = require("path");
const { chromium } = require("@playwright/test");

module.exports = async () => {
  const baseURL  = process.env.BASE_URL   || "http://127.0.0.1:8010";
  const username = process.env.ADMIN_USER || "admin";
  const password = process.env.ADMIN_PASS || "admin";
  const storage  = path.resolve("storage","user.json");

  const browser = await chromium.launch();
  const ctx = await browser.newContext();
  const page = await ctx.newPage();

  // /admin/ -> loginliyse direkt dashboard
  await page.goto(`${baseURL}/admin/`, { waitUntil: "domcontentloaded", timeout: 30000 });

  // login formu varsa doldur
  const hasLogin = await page.locator("#id_username, input[name='username']").first().isVisible().catch(()=>false);
  if (hasLogin){
    await page.fill("#id_username, input[name='username']", username);
    await page.fill("#id_password, input[name='password']", password);
    await Promise.all([
      page.waitForNavigation({ waitUntil: "networkidle", timeout: 30000 }).catch(()=>null),
      page.locator("text=/Log in|Giriş|Oturum Aç/i, input[type='submit']").first().click()
    ]);
  }

  // başarı: URL /admin/ içeriyor veya dashboard seçicileri görünüyor
  const okByUrl = page.url().includes("/admin/");
  const okByUi  = await page.locator("#content, .dashboard, .app-index").first().isVisible().catch(()=>false);
  if (!okByUrl && !okByUi){
    await page.goto(`${baseURL}/admin/`, { waitUntil: "domcontentloaded", timeout: 30000 });
  }

  fs.mkdirSync(path.dirname(storage), { recursive: true });
  await ctx.storageState({ path: storage });
  await browser.close();
  console.log(`[globalSetup] storage created at: ${storage}`);
};