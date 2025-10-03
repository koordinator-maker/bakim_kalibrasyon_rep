const { test, expect } = require("@playwright/test");
test.use({ storageState: "storage/user.json" });

test("admin anasayfa erişim", async ({ page }) => {
  await page.goto("http://127.0.0.1:8010/admin/");
  await page.screenshot({ path: "admin_home.png" });
  
  const url = page.url();
  console.log("Final URL:", url);
  
  const bodyText = await page.locator("body").textContent();
  console.log("Body preview:", bodyText.substring(0, 300));
  
  expect(url).not.toContain("login");
});

