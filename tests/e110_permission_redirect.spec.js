/**
 * E110 — Yetki/403: login yokken admin equipment sayfası -> login'e yönlenir
 */
import { test, expect, chromium } from "@playwright/test";

test("E110 - Yetkisiz erişim login sayfasına düşmeli", async ({ browser }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  // Yeni izole page (state yok)
  const context = await browser.newContext(); 
  const page = await context.newPage();

  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(/\/admin\/login\//); // Django tipik davranış: 302->login
  await context.close();
});