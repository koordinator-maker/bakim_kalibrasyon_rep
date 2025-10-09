import { chromium } from "@playwright/test";

export default async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  const base = process.env.BASE_URL || "http://127.0.0.1:8010";

  await page.goto(base + "/admin/");
  await page.fill("#id_username", process.env.ADMIN_USER || "");
  await page.fill("#id_password", process.env.ADMIN_PASS || "");

  // CSS ve text selector karÄ±ÅŸtÄ±rma! getByRole kullan
  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.getByRole("button", { name: /log in/i }).click()
    // Alternatif saf CSS istersek: page.locator('input[type="submit"]').first().click()
  ]);

  await page.getByText("Django administration").waitFor({ timeout: 8000 });
  await context.storageState({ path: "storage/user.json" });
  await browser.close();
};

