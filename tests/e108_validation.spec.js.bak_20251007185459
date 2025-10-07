import { test, expect } from "@playwright/test";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

test("E108 - Zorunlu alan doğrulaması (boş gönderimde hata beklenir)", async ({ page }) => {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });
  const submit = page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await submit.click();

  const anyError = page.locator(".errorlist, .errors, .invalid-feedback, .field-error, .errornote");
  await expect(anyError, "Boş gönderimde doğrulama hatası beklenir").toHaveCountGreaterThan(0);
});