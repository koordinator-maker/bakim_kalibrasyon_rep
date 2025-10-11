import { test, expect } from "@playwright/test";
import { createMinimalEquipment, successFlashExists } from "./helpers_e10x.js";
test("E103 - Equipment Kaydetme (dinamik doldurma)", async ({ page }) => {
  await createMinimalEquipment(page);
  const ok = await successFlashExists(page);
  const url = page.url();
  const isList   = /\/admin\/maintenance\/equipment\/?$/.test(url);
  const isChange = /\/admin\/maintenance\/equipment\/\d+\/change\/?/.test(url);
  expect(ok || isList || isChange, `Kayıt sonrası beklenen sayfa/mesaj gelmedi (url=${url})`).toBeTruthy();
});