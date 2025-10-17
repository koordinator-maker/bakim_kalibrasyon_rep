import { test } from "@playwright/test";

test("Screenshot BEFORE - 404 Error", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/maintenance/equipment/add/");
  await page.waitForTimeout(3000);
  await page.screenshot({ path: "before-404.png", fullPage: true });
  console.log("✅ Screenshot saved: before-404.png");
});
