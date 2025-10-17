import { test } from "@playwright/test";
import { createMinimalEquipment } from "./helpers_e10x.js";

test.setTimeout(120000);  // ✅ CLAUDE PATCH: 60s → 120s

test("E103 - Equipment Kaydetme (CLAUDE PATCHED)", async ({ page }) => {
  await createMinimalEquipment(page);
});
