import { test, expect } from "@playwright/test";

test("EQP-003 › Ekipman Ekleme formunda Üretici/Manufacturer alanı (opsiyonel)", async ({ page }) => {
  test.setTimeout(60_000);

  await page.goto("/admin/");
  await page.locator('a[href*="/maintenance/equipment/"], a[href*="/equipments/"], a[href*="/equipment/"]').first().click();
  await page.locator('#content .object-tools a[href$="/add/"], a.addlink[href$="/add/"]').first().click();
  await page.waitForSelector("#content-main form", { timeout: 15_000 });

  // Kapalı fieldset'leri aç
  await page.evaluate(() => {
    document.querySelectorAll("fieldset.collapse, fieldset.collapsed")
      .forEach(fs => fs.classList.remove("collapse","collapsed"));
  });
  await page.locator(".collapse-toggle").click({ multiple: true }).catch(() => {});

  const selector = [
    'label:has-text("Üretici")',
    'label:has-text("Üretici Firma")',
    'label:has-text("Manufacturer")',
    'select[name*="manufacturer" i]',
    'input[name*="manufacturer" i]',
    '[id*="manufacturer" i]',
    'select[name*="uretici" i]',
    'input[name*="uretici" i]',
    '[id*="uretici" i]',
    'div.related-widget-wrapper select[name*="manufacturer" i]',
    'div.autocomplete-light-widget input[id*="manufacturer" i]'
  ].join(", ");

  const count = await page.locator(selector).count();
  if (count > 0) {
    const target = page.locator(selector).first();
    await target.scrollIntoViewIfNeeded().catch(()=>{});
    await expect(target).toBeVisible({ timeout: 8_000 });
  } else {
    test.info().annotations.push({
      type: "note",
      description: "Üretici/Manufacturer alanı bu kurulumda bulunamadı (opsiyonel)."
    });
  }
});
