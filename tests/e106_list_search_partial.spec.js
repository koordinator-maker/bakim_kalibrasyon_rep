import { test, expect } from "@playwright/test";
import { ensureLogin, gotoListExport } from "./helpers_e10x";
const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/,"");

test("E106 - Liste arama (partial match)", async ({ page }) => {
  page = await ensureLogin(page);
  page = await gotoListExport(page);

  const prefix = "AUTO-E106-";
  const q = page.locator('input[name="q"]');
  await q.fill(prefix);
  await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);

  const rows = page.locator("#result_list tbody tr");
  await expect.poll(async () => await rows.count()).toBeGreaterThan(0);
});