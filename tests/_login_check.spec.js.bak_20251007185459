import { test, expect } from "@playwright/test";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("login check", async ({ page }) => {
  // Eğer zaten giriş yapılmışsa login sayfasına zorlamak için önce logout dene
  await page.goto(`${BASE}/admin/logout/`, { waitUntil: "domcontentloaded" }).catch(()=>{});
  await page.goto(`${BASE}/admin/login/`, { waitUntil: "domcontentloaded" });

  const user = process.env.ADMIN_USER || "admin";
  const pass = process.env.ADMIN_PASS || "admin";

  // Giriş formu varsa doldur; yoksa zaten girişlidir => test geçer
  const userInput = page.locator("#id_username").or(page.getByLabel(/Username|Kullanıcı adı/i));
  if (await userInput.count()) {
    await userInput.fill(user);
    await page.locator("#id_password").or(page.getByLabel(/Password|Parola|Şifre/i)).fill(pass);
    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded" }),
      page.locator('input[type="submit"], button[type="submit"]').first().click()
    ]);
    await expect(page).not.toHaveURL(/\/admin\/login\//);
  } else {
    await expect(page).not.toHaveURL(/\/admin\/login\//);
  }
});