import { test } from "@playwright/test";

test("Screenshot AFTER - Working Page", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/");
  await page.waitForTimeout(3000);
  await page.screenshot({ path: "after-working.png", fullPage: true });
  console.log("✅ Screenshot saved: after-working.png");
});
