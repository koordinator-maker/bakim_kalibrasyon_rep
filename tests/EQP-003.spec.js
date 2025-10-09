import { test, expect } from "@playwright/test";

test("EQP-003 › Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
  await page.goto("/admin/");
  // Equipment changelist: /maintenance/equipment/ veya /equipments/
  await page.locator('a[href*="/maintenance/equipment/"], a[href*="/equipments/"], a[href*="/equipment/"]')
           .first()
           .click({ timeout: 10000 });

  const addBtn = page
    .locator("#content .object-tools a[href$='/add/'], #content a.addlink[href$='/add/']")
    .first();
  await addBtn.click();

  await expect(page.locator("#id_manufacturer, select[name='manufacturer'], #id_uretici_firma"))
    .toBeVisible({ timeout: 8000 });
});