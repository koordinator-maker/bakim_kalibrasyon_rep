import { test, expect } from "@playwright/test";

test("EQP-Create › Ekipman kaydı yapılabiliyor", async ({ page }) => {
  const name = "AUTO-EQ-" + Date.now();

  await page.goto("/admin/");
  await page.locator('a[href*="/equipment/"], a[href*="/equipments/"]').first().click();
  await page.locator('#content .object-tools a[href$="/add/"], a.addlink[href$="/add/"]').first().click();
  await page.waitForSelector("#content-main form");

  // En mantıklı zorunlu alanı doldur
  const required = page.locator("form [required]").first();
  if (await required.count()) {
    await required.fill(name);
  } else {
    const nameLike = page.locator('form input[name*="name" i], form input[id*="name" i]').first();
    await nameLike.fill(name);
  }

  const save = page.locator('input[name="_save"], button:has-text("Save")').first();
  await save.click();

  await expect(page.locator(".messagelist, .messages")).toContainText(/successfully|başarıyla/i);
  await expect(page.locator("#result_list, table")).toContainText(name);
});
