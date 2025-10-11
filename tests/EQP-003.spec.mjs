import { test, expect } from "@playwright/test";
import { gotoAdd } from "./helpers_e10x.js";
test("EQP-003 - Manufacturer alanı görünür olmalı (varsa)", async ({ page }) => {
  await gotoAdd(page);
  const manu = page.locator('#id_manufacturer, [name*="manufacturer"]').first();
  await expect.soft(manu).toBeVisible({ timeout: 3000 });
});