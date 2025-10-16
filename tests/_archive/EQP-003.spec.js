import { test, expect } from "@playwright/test";
import { gotoAdd } from "../helpers_e10x.js";

test.setTimeout(60000);

test("Ekipman Ekleme formunda Üretici/Manufacturer alanı (opsiyonel)", async ({ page }) => {
  await gotoAdd(page);
  
  const manu = page.locator('#id_manufacturer, [name*="manufacturer"]').first();
  const exists = await manu.count() > 0;
  
  if(exists){
    await expect.soft(manu).toBeVisible({ timeout: 5000 });
  }
});

