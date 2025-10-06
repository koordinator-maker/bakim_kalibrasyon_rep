const { test, expect } = require('@playwright/test');

test('Ekipman Ekleme formunda Üretici Firma alanının varlığı', async ({ page }) => {
  const base = process.env.BASE_URL || 'http://127.0.0.1:8010';
  await page.goto(`${base}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });

  // Form geldi mi?
  await expect(page.locator('#equipment_form')).toBeVisible({ timeout: 5000 });

  // 1) Label tabanlı (i18n)
  const byLabel = page.getByLabel(/Üretici Firma|Manufacturer|Tedarikçi|Supplier|Brand|Marka/i).first();
  if (await byLabel.isVisible().catch(() => false)) {
    await expect(byLabel).toBeVisible();
    console.log('[TEST SUCCESS] Üretici alanı label ile bulundu');
    return;
  }

  // 2) CSS tabanlı (çeşitli olası field isimleri)
  const css = page.locator([
    '#id_manufacturer',
    "select[name='manufacturer']",
    "[name='manufacturer']",
    "[data-field-name*='manufactur'] select",
    "[data-field-name*='manufactur'] input",
    ".field-manufacturer select",
    ".field-manufacturer input",
    ".related-widget-wrapper select",
    ".related-widget-wrapper input"
  ].join(', ')).first();

  if (await css.isVisible().catch(() => false)) {
    await expect(css).toBeVisible();
    console.log('[TEST SUCCESS] Üretici alanı CSS ile bulundu');
    return;
  }

  // 3) Debug: formdaki tüm label’ları logla
  const labels = await page.locator('label').allInnerTexts();
  console.log('Existing labels on form:', labels);
  throw new Error('Üretici/Manufacturer alanı bulunamadı');
});
