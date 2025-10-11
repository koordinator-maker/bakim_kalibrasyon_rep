import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x";

test("E106 - Listeyi arama kutusuyla filtrele", async ({ page }) => {
  await ensureLogin(page);
  await gotoList(page);

  const table = page.locator("#result_list");
  await expect(table).toBeVisible({ timeout: 10000 });

  const q = page.locator('input[name="q"]');
  await expect(q).toBeVisible();

  const term = "AUTO";
  await q.fill(term);
  await Promise.all([
    page.waitForLoadState("domcontentloaded"),
    q.press("Enter"),
  ]);

  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?q=/);
  await expect(table).toBeVisible();
  await expect(q).toHaveValue(term);
});