import { test, expect } from "@playwright/test";
import { ensureLogin } from "./helpers_e10x";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/,"");

test("E108 - Zorunlu alan uyarısı", async ({ page }) => {
  // 1) Oturum aç
  page = await ensureLogin(page);

  // 2) Add formuna git
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // 3) Boş gönder
  const nameInput = page.locator("#id_name");
  await nameInput.fill("");
  const submit = page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await Promise.all([ page.waitForLoadState("domcontentloaded"), submit.click() ]);

  // 4) Hata sinyallerinin tüm olası seçicileri
  const candidates = [
    'ul.errorlist li',
    '#id_name_error li',
    '.errornote',
    '.form-row.errors',
    'li:has-text("This field is required")',
    'li:has-text("required")'
  ];

  // 5) Toplam hata sayısı > 0 olana kadar bekle
  await expect.poll(async () => {
    let total = 0;
    for (const sel of candidates) total += await page.locator(sel).count();
    return total;
  }).toBeGreaterThan(0);
});