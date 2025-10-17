import { test, expect } from "@playwright/test";
import { createMinimalEquipment } from "../helpers_e10x.js";

test.setTimeout(60000);

test("Ekipman kaydı yapılabiliyor", async ({ page }) => {
  await createMinimalEquipment(page);
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\//);
});

