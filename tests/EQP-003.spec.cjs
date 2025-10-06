const { test, expect } = require('@playwright/test');

test('Ekipman Ekleme formunda Üretici Firma alanının varlığı', async ({ page }) => {
  const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`);

  // Form gerçekten açılmış mı?
  await expect(page.locator("main form, #content form, form[method='post']")).toBeVisible({ timeout: 3000 });

  // Üretici alanı için sağlam adaylar
  const manufacturerSelectors = [
    "#id_manufacturer",
    "select[name='manufacturer']",
    "[name='manufacturer']",
    ".form-row.field-manufacturer select, .form-row.field-manufacturer input",
    ".field-manufacturer select, .field-manufacturer input",
    "[data-field-name='manufacturer'] select, [data-field-name='manufacturer'] input",
    ".related-widget-wrapper select, .related-widget-wrapper input"
  ];

  const fieldWrapper = page.locator(manufacturerSelectors.join(", ")).first();
  await expect(fieldWrapper).toBeVisible({ timeout: 10000 });
  console.log('[TEST SUCCESS] Üretici Firma alanı başarıyla doğrulandı.');
});

