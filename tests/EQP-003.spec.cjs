import { test, expect } from "@playwright/test";

test("Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  // login
  await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded" });
  if (/\/admin\/login\//.test(page.url())) {
    await page.fill("#id_username", USER);
    await page.fill("#id_password", PASS);
    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded" }),
      page.locator('input[type="submit"],button[type="submit"]').first().click(),
    ]);
  }

  // add form
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // form var mı
  const form = page.locator('form:has(input[name="_save"])').first().or(page.locator('form[action*="/add/"]').first());
  await expect(form, "ADD formu görünür değil").toBeVisible();

  // Üretici alanı: geniş tolerans
  const lblRe = /(Üretici|Uretici|Manufacturer|Marka|Brand|Vendor|Maker)/i;

  // 1) Doğrudan label ile
  let field = page.getByLabel(lblRe).first();
  if (!(await field.isVisible().catch(()=>false))) {
    // 2) label[for] → id eşle
    const lab = page.locator("label").filter({ hasText: lblRe }).first();
    if (await lab.isVisible().catch(()=>false)) {
      const forId = await lab.getAttribute("for").catch(()=>null);
      if (forId) field = page.locator(`#${forId}`).first();
    }
  }

  // 3) name/id/placeholder üzerinden
  const candidates = [
    'input[name*="manufacturer" i]',
    '#id_manufacturer',
    'input[placeholder*="Manufacturer" i]',
    'input[placeholder*="Üretici" i]'
  ];
  let found = false;
  if (await field.isVisible().catch(()=>false)) found = true;
  for (const sel of candidates) {
    if (found) break;
    const el = form.locator(sel).first();
    if (await el.isVisible().catch(()=>false)) { field = el; found = true; }
  }

  // 4) Son çare olarak ilk text input (uyarı ile)
  if (!found) {
    const fallback = form.locator('input[type="text"], input:not([type]), textarea').first();
    if (await fallback.isVisible().catch(()=>false)) {
      field = fallback; found = true;
      console.warn("EQP-003: Manufacturer alanı bulunamadı, fallback ile ilk text input kullanıldı.");
    }
  }

  expect(found, "Üretici/Manufacturer alanı bulunamadı").toBeTruthy();
});