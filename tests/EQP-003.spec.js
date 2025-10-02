// Rev: 2025-10-02 18:05 r12
// tests/EQP-003.spec.js
const { test, expect } = require("@playwright/test");

test.describe("EQP-003", () => {
  test("Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
    // Admin -> login düşme kontrolü
    await page.goto("/admin/", { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.url(), { timeout: 5000 }).not.toMatch(/\/admin\/login\/?/);

    // Changelist -> (_direct dahil) Add sayfasına git
    await page.goto("/admin/maintenance/equipment/", { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.url(), { timeout: 7000 })
      .toMatch(/\/admin\/maintenance\/equipment(?:\/_direct)?\/?$/);

    // Add butonu ya da direkt URL
    const addBtn = page.locator(".object-tools .addlink, a.addlink, a[href$='/add/'], a[href*='/equipment/add/'], a[href*='/equipment/_direct/add/']").first();
    if (await addBtn.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState("domcontentloaded").catch(()=>{}), addBtn.click() ]);
    } else {
      for (const u of ["/admin/maintenance/equipment/_direct/add/","/admin/maintenance/equipment/add/"]) {
        await page.goto(u, { waitUntil: "domcontentloaded" });
        if (!/\/admin\/login\/?/.test(page.url())) break;
      }
    }

    // Yükleme toleransı
    await page.waitForTimeout(500);

    //  ✅ 1) Label varlığı (TR/EN)
    const label = page.locator("label:has-text('Üretici Firma'), label:has-text('Üretici'), label:has-text('İmalatçı'), label:has-text('Manufacturer')");
    await expect(label.first()).toBeVisible({ timeout: 8000 });

    //  ✅ 2) Field wrapper varlığı (Django admin varyantları)
    const wrapper = page.locator(".form-row.field-manufacturer, .field-manufacturer, [data-field-name='manufacturer'], .related-widget-wrapper");
    await expect(wrapper.first()).toBeVisible({ timeout: 8000 });

    // Not: İleride gerçek inputu hedeflemek istersek Inspector ile kesin locator alıp
    //  const input = page.locator('#<id>'); await expect(input).toBeVisible();
    //  satırını ekleyebiliriz.
  });
});
