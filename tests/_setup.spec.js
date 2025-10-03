// tests/_setup.spec.js
import { test as setup, expect } from "@playwright/test";
import fs from "fs";
import path from "path";

const authFile = path.join(process.cwd(), "storage", "user.json");

setup("login state -> storage/user.json", async ({ page, context }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "hp";
  const PASS = process.env.ADMIN_PASS || "A1234";

  // 1) Önce admin köke git (login veya dashboard'a düşer)
  await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded", timeout: 30000 });

  // 2) Login sayfasında mıyız? Basit ve tema-bağımsız tespit
  const loginMarker = page.locator("form[action*='login'], input[name='username'], #id_username").first();
  const isLogin = await loginMarker.isVisible().catch(() => false);

  if (isLogin) {
    // 3) Giriş yap
    const userInput = page.locator('input[name="username"], #id_username').first();
    const passInput = page.locator('input[name="password"], #id_password').first();
    await userInput.fill(USER, { timeout: 5000 });
    await passInput.fill(PASS, { timeout: 5000 });

    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded", timeout: 15000 }),
      page.locator('input[type="submit"], button[type="submit"]').click(),
    ]);
  }

  // 4) Başarı ölçütü: login URL'inde olmamak ve login formunun DOM'da olmaması
  await expect(page).not.toHaveURL(/\/admin\/login\/?/);
  await expect(page.locator("form[action*='login'], input[name='username'], #id_username")).toHaveCount(0, { timeout: 3000 });

  // 5) Session kaydet
  await context.storageState({ path: authFile });
  if (!fs.existsSync(authFile)) throw new Error("storage/user.json yazılamadı");
  console.log(`[SETUP SUCCESS] Saved: ${authFile} — URL: ${page.url()}`);
});

