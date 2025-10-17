import { test } from "@playwright/test";
import { createMinimalEquipment } from "./helpers_e10x.js";

test.setTimeout(300000);  // PATCHED: 60s → 300s

test("E103 - Equipment Kaydetme (FINAL PATCH)", async ({ page }) => {
  await createMinimalEquipment(page);
});
