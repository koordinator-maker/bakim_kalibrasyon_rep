import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";
test("E109 - Arama sonrası sonuçta kayıt bulunmalı (bilgi amaçlı)", async ({ page }) => {
  await ensureLogin(page); await gotoList(page);
  const q = page.locator('input[name="q"]'); await expect(q).toBeVisible();
  const prefix = "AUTO"; await q.fill(prefix);
  await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?q=/);
  // Bilgi: satır sayısını soft kontrol et (fail durumunda raporlanır)
  await expect.soft(page.locator("#result_list tbody tr")).toHaveCountGreaterThan(0);
});