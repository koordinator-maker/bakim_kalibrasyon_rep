import { test, expect } from "@playwright/test";
import { createMinimalEquipment, gotoList, save } from "./helpers_e10x.js";

test.setTimeout(60000);

test("E107 - Ekipmanı düzenle ve kaydet", async ({ page }) => {
  await createMinimalEquipment(page);
  
  if (!/\/admin\/maintenance\/equipment\/\d+\/change\/?/.test(page.url())) {
    await gotoList(page);
    await page.locator("#result_list tbody tr").first().click();
  }
  
  await page.locator('#id_name, input[name="name"]').first().fill(`EDITED-${Date.now()}`);
  await save(page);
  
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\//);
});

