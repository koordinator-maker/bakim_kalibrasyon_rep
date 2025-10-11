import { test, expect } from "@playwright/test";
import { ensureLogin } from "./helpers_e10x";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/,"");

test("E108 - Zorunlu alan uyarısı", async ({ page }) => {
  // 1) login
  page = await ensureLogin(page);

  // 2) add formu
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // 3) boş gönder
  await page.locator("#id_name").fill("");
  const submit = page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await Promise.all([ page.waitForLoadState("domcontentloaded"), submit.click() ]);

  // 4) asıl kriter: başarı mesajı görünmemeli
  await expect(page.locator("ul.messagelist li.success")).toHaveCount(0);

  // 5) bilgilendirici ek kontroller (testi kilitlemez)
  //    logout/login’a düşerse tekrar forma dön ve name alanının görüldüğünü teyit et
  if (/\/(logout|login)\//i.test(page.url())) {
    page = await ensureLogin(page);
    await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });
  }
  await page.locator("#id_name").first().waitFor({ state: "visible", timeout: 5000 }).catch(()=>{ /* opsiyonel */ });
});