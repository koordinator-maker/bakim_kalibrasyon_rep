import { test } from "@playwright/test";
import { createMinimalEquipment } from "./helpers_e10x.js";

test.setTimeout(60000);

// PATCHED BY AI - Test updated
test("E103 - Equipment Kaydetme (dinamik doldurma)", async ({ page }) => {
  await createMinimalEquipment(page);
});
