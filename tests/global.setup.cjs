const path = require("path");
const fs = require("fs");
const { chromium } = require("@playwright/test");

async function loginAdmin(page, BASE, USER, PASS) {
  await page.goto(`${BASE}/admin/login/`, { waitUntil: "domcontentloaded", timeout: 20000 });
  // login sayfasında değilsek zaten authenticated
  if (!/\/admin\/login\//.test(page.url())) return;

  await page.fill("#id_username", USER);
  await page.fill("#id_password", PASS);
  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.locator('input[type="submit"],button[type="submit"]').first().click(),
  ]);
}

module.exports = async () => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  const stateFile = path.join(__dirname, ".auth", "admin.json");
  fs.mkdirSync(path.dirname(stateFile), { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    // küçük bir retry
    let ok = false, lastErr;
    for (let i = 0; i < 3 && !ok; i++) {
      try { await loginAdmin(page, BASE, USER, PASS); ok = true; }
      catch (e) { lastErr = e; await page.waitForTimeout(500*(i+1)); }
    }
    if (!ok) throw lastErr;

    await context.storageState({ path: stateFile });
  } finally {
    await context.close().catch(()=>{});
    await browser.close().catch(()=>{});
  }
};