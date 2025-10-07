/**
 * E108 — Zorunlu alan validasyonu (name boş bırak)
 */
import { test, expect } from "@playwright/test";
import { loginIfNeeded } from "./_helpers.equip";

test("E108 - Zorunlu alan uyarısı", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  await loginIfNeeded(page, BASE, USER, PASS);
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form).toBeVisible();

  // name boş bırak → kaydet
  const save = form.locator('input[name="_save"],button[type="submit"],input[type="submit"]').first();
  await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);

  // farklı dillerde tipik hata metinleri
  const err = page.locator(
    '.errorlist li, .errornote, [class*="error"]'
  ).filter({ hasText: /(required|zorunlu|obligatoire|obligatorio|erforderlich|necessario)/i });
  await expect(err, "Zorunlu alan uyarısı görünmedi").toBeVisible();
});