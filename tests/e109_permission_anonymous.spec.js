import { test, expect } from "@playwright/test";

const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("E109 - Yetkisiz erişim: anonim kullanıcı add sayfasına erişemez", async ({ browser, page }) => {
  // Mevcut oturumu etkisizleştir (savunma amaçlı)
  await page.goto(`${BASE}/admin/logout/`, { waitUntil: "domcontentloaded" }).catch(() => {});

  // Tamamen temiz, çerezsiz bir context aç
  const ctx = await browser.newContext({ storageState: undefined });
  const anon = await ctx.newPage();

  // Add sayfasına anonim olarak git
  await anon.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // Login'e düştüğünü iki şekilde kabul et: URL veya login formunun görünmesi
  const loginField = anon.locator('#id_username').or(anon.getByLabel(/Username|Kullanıcı adı/i));
  const onLoginUrl = /\/admin\/login\//.test(anon.url());
  const fieldVisible = await loginField.first().isVisible().catch(() => false);

  expect(onLoginUrl || fieldVisible).toBeTruthy();

  await ctx.close();
});