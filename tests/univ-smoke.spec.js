import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";
test("UNIV-SMOKE — Page opens and has Title & H1", async ({ page, baseURL }) => {
  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  const resp = await page.goto(url, { waitUntil: "domcontentloaded" });
  expect(resp?.ok()).toBeTruthy();
  await expect(page).toHaveTitle(/.+/);
  expect(await page.locator("h1").count()).toBeGreaterThan(0);
});