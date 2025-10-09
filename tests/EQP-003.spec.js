import { test, expect } from "@playwright/test";

test("EQP-003 › Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
  await page.goto("/admin/");
  await page.locator('a[href*="/maintenance/equipment/"], a[href*="/equipments/"], a[href*="/equipment/"]').first().click({ timeout: 10000 });

  const addBtn = page.locator("#content .object-tools a[href$='/add/'], #content a.addlink[href$='/add/']").first();
  await addBtn.click();

  // Collapsed fieldset’leri genişlet
  await page.locator('fieldset.module.collapse .collapse-toggle, fieldset.collapsed .collapse-toggle')
           .click({ multiple: true, timeout: 2000 }).catch(() => {});

  // Label veya input/select fallback’leri
  const byLabel   = page.getByLabel(/(Üretici\s*Firma|Manufacturer)/i);
  const fallbacks = page.locator('#id_manufacturer, select[name="manufacturer"], #id_uretici_firma, [name*="manufacturer"], [id*="manufacturer"]');
  await expect(byLabel.or(fallbacks)).toBeVisible({ timeout: 8000 });
});
