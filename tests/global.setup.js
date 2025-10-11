import { chromium } from "@playwright/test";
import { loginAdmin } from "./_helpers/auth.js";

const STATE = "tests/.auth/admin.json";

export default async function globalSetup() {
  const baseURL = process.env.BASE_URL || "http://127.0.0.1:8010";
  const user = process.env.ADMIN_USER || "admin";
  const pass = process.env.ADMIN_PASS || "admin";

  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  await loginAdmin(page, baseURL, user, pass);

  // Teyit: /admin/ açılabiliyor mu?
  const root = baseURL.replace(/\/$/, "");
  await page.goto(root + "/admin/", { waitUntil: "domcontentloaded" });
  const loggedIn = !/\/admin\/login\//.test(page.url());
  if (!loggedIn) {
    await browser.close();
    throw new Error("globalSetup: Login başarısız. ADMIN_USER/ADMIN_PASS ve admin yetkilerini kontrol edin.");
  }

  await context.storageState({ path: STATE });
  await browser.close();
}