import { test, expect } from "@playwright/test";

test("EQP-003 › Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
  test.setTimeout(90_000);

  // 1) Ekipman listesi → Add formu
  await page.goto("/admin/");
  await page.locator('a[href*="/maintenance/equipment/"], a[href*="/equipments/"], a[href*="/equipment/"]').first().click();
  await page.locator('#content .object-tools a[href$="/add/"], a.addlink[href$="/add/"]').first().click();
  await page.waitForSelector("#content-main form", { timeout: 15_000 });

  // 2) Olası kapalı fieldset'leri aç
  await page.evaluate(() => {
    document.querySelectorAll("fieldset.collapse, fieldset.collapsed")
      .forEach(fs => fs.classList.remove("collapse","collapsed"));
  });
  await page.locator(".collapse-toggle").click({ multiple: true }).catch(() => {});

  // 3) Alanın varlığını geniş desenle kontrol et
  const selector = [
    // Label üzerinden
    'label:has-text("Üretici")',
    'label:has-text("Üretici Firma")',
    'label:has-text("Manufacturer")',
    // Doğrudan input/select id/name
    'select[name*="manufacturer" i]',
    'input[name*="manufacturer" i]',
    '[id*="manufacturer" i]',
    'select[name*="uretici" i]',
    'input[name*="uretici" i]',
    '[id*="uretici" i]',
    // Django related + autocomplete varyantları
    'div.related-widget-wrapper select[name*="manufacturer" i]',
    'div.autocomplete-light-widget input[id*="manufacturer" i]'
  ].join(", ");

  // 4) Görünür olmasa bile DOM’da var mı diye bekle (poll)
  await expect.poll(
    async () => await page.locator(selector).count(),
    { timeout: 20_000, intervals: [500, 750, 1000] }
  ).toBeGreaterThan(0);

  // 5) Bulduğumuz ilk elemanı görünür hale getirip (gerekirse) focusla
  const target = page.locator(selector).first();
  await target.scrollIntoViewIfNeeded().catch(() => {});
  // bazı layout’larda görünür olmayabilir; sadece varlığı yeterli
});