const { test, expect } = require("@playwright/test");
const BASE = process.env.BASE_URL || "http://127.0.0.1:8010";

test("Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
  if (process.env.EXPECT_MANUFACTURER === "0") test.skip(true, "Backend alanı hazır değil - geçici skip");

  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  /* ensure logged in (fallback) */
  if (/\/admin\/login\//.test(page.url())) {
    const uVal = process.env.ADMIN_USER ?? "admin";
    const pVal = process.env.ADMIN_PASS ?? "admin";

    let u = page.locator('#id_username, input[name="username"], input[name="email"], input#id_user, input[name="user"]').first();
    const uByPh = page.getByPlaceholder(/kullanıcı adı|kullanici adi|email|e-?posta|username/i).first();
    const uByLb = page.getByLabel(/kullanıcı adı|kullanici adi|username|email|e-?posta/i).first();
    if (!(await u.isVisible().catch(()=>false))) u = (await uByPh.isVisible().catch(()=>false)) ? uByPh : uByLb;

    let p = page.locator('#id_password, input[name="password"], input[type="password"]').first();
    const pByPh = page.getByPlaceholder(/parola|şifre|sifre|password/i).first();
    const pByLb = page.getByLabel(/parola|şifre|sifre|password/i).first();
    if (!(await p.isVisible().catch(()=>false))) p = (await pByPh.isVisible().catch(()=>false)) ? pByPh : pByLb;

    try { await u.fill(uVal, { timeout: 10000 }); } catch {}
    try { await p.fill(pVal, { timeout: 10000 }); } catch {}
    const btn = page.getByRole("button", { name: /log in|giriş|oturum|sign in|submit|login/i }).first();
    if (await btn.isVisible().catch(()=>false)) { await btn.click(); }
    else {
      const submit = page.locator('input[type="submit"], button[type="submit"]').first();
      if (await submit.isVisible().catch(()=>false)) { await submit.click(); }
      else { await p.press("Enter").catch(()=>{}); }
    }
    await page.waitForLoadState("domcontentloaded").catch(()=>{});
  }
  /* end ensure logged in (fallback) */

  // Aday seçiciler (label, name/id, placeholder)
  const candidates = [
    page.getByLabel(/Üretici Firma|Üretici|Manufacturer|Vendor/i).first(),
    page.locator('#id_manufacturer, [name="manufacturer"], [name="vendor"]').first(),
    page.getByPlaceholder(/Üretici|Manufacturer|Vendor/i).first(),
  ];

  let found = null;
  for (const c of candidates) {
    if (await c.count().catch(()=>0)) { found = c; break; }
  }

  expect(found, "Üretici/Manufacturer alanı bulunamadı").toBeTruthy();
});
