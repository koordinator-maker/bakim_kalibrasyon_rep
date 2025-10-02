// tests/_setup.spec.js
import { test as setup, expect } from "@playwright/test";
import fs from "fs";
import path from "path";

const authFile = path.join(process.cwd(), "storage", "user.json");

setup("login state -> storage/user.json", async ({ page, context }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "hp";
  const PASS = process.env.ADMIN_PASS || "A1234";
  const loginUrl = `${BASE}/admin/login/`;

  // 1) Login sayfasına git
  await page.goto(loginUrl, { waitUntil: "domcontentloaded", timeout: 30000 });

  // 2) Form elemanları görünür olmalı
  const userInput = page.locator('input[name="username"], #id_username').first();
  const passInput = page.locator('input[name="password"], #id_password').first();
  await expect(userInput).toBeVisible({ timeout: 5000 });
  await expect(passInput).toBeVisible({ timeout: 5000 });

  // 3) Giriş yap
  await userInput.fill(USER);
  await passInput.fill(PASS);
  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded", timeout: 15000 }),
    page.locator('input[type="submit"], button[type="submit"]').click(),
  ]);

  // 4) Başarı ölçütü (tema bağımsız):
  //    - login sayfasında OLMAMAK
  //    - login form elemanlarının DOM’da OLMAMASI
  await expect(page).not.toHaveURL(/\/admin\/login\/?/);
  await expect(page.locator("form[action*='login'], input[name='username'], #id_username")).toHaveCount(0, { timeout: 3000 });

  // (Opsiyonel) Django varsayılan session cookie kontrolü
  try {
    const cookies = await context.cookies();
    const hasSession = cookies.some(c => c.name === "sessionid");
    if (!hasSession) console.warn("[WARN] 'sessionid' çerezi görülmedi; özelleştirilmiş session adı olabilir.");
  } catch {}

  // 5) Session kaydet
  await context.storageState({ path: authFile });
  if (!fs.existsSync(authFile)) throw new Error("storage/user.json yazılamadı");
  console.log(`[SETUP SUCCESS] Saved: ${authFile} — URL: ${page.url()}`);
});
