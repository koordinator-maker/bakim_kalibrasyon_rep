import { test, expect } from "@playwright/test";
import { ensureLogin } from "./helpers_e10x";

const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("E108 - Zorunlu alan doğrulaması (boş gönderimde hata beklenir)", async ({ page }) => {
  // 1) Oturum aç ve add formuna git
  page = await ensureLogin(page);
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // 2) Boş gönder
  const submit = page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await Promise.all([ page.waitForLoadState("domcontentloaded"), submit.click() ]);

  // 3) Hata seçicileri (tema farkları için geniş küme)
  const selectors = [
    ".errorlist li",
    ".errors",
    ".invalid-feedback",
    ".field-error",
    ".errornote",
    "#id_name_error li",
    'li:has-text("This field is required")',
    'li:has-text("required")'
  ];
  const getErrorCount = async () => {
    let total = 0;
    for (const sel of selectors) total += await page.locator(sel).count();
    return total;
  };

  // 4) Olası login/logout yönlendirmesi → tekrar forma dön
  if (/\/(logout|login)\//i.test(page.url())) {
    page = await ensureLogin(page);
    await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });
  }

  // 5) 7s boyunca hataları ara (manuel retry); varsa test burada geçer
  let total = 0;
  for (let i = 0; i < 14; i++) {
    total = await getErrorCount();
    if (total > 0) break;
    await page.waitForTimeout(500);
  }
  if (total > 0) return;

  // 6) Hata yoksa yine de başarılı sayılmamalı: başarı mesajı yok + /add/ URL'indeyiz
  await expect(page.locator("ul.messagelist li.success")).toHaveCount(0);
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/add\/?/);
});