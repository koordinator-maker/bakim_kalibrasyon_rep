const { chromium } = require("@playwright/test");
const fs   = require("fs");
const path = require("path");
const { loginAdmin } = require("./_helpers/auth.cjs");

const STATE = path.resolve(__dirname, ".auth", "admin.json"); // mutlak

module.exports = async function globalSetup() {
  const baseURL = process.env.BASE_URL  || "http://127.0.0.1:8010";
  const user    = process.env.ADMIN_USER || "admin";
  const pass    = process.env.ADMIN_PASS || "admin";

  fs.mkdirSync(path.dirname(STATE), { recursive: true });

  const headless = process.env.PW_HEAD ? false : true;
  const browser  = await chromium.launch({ headless });
  const context  = await browser.newContext();
  const page     = await context.newPage();

  console.log("[setup] __dirname =", __dirname);
  console.log("[setup] will write state to:", STATE);

  await loginAdmin(page, baseURL, user, pass);

  const root = baseURL.replace(/\/$/, "");
  await page.goto(root + "/admin/", { waitUntil: "domcontentloaded" });

  const loggedIn = !/\/admin\/login\//.test(page.url());
  console.log("[setup] after login url:", page.url(), "loggedIn:", loggedIn);
  if (!loggedIn) {
    
// --- DEBUG: drop evidence when login fails ---
await page.screenshot({
  path: require("path").resolve(__dirname, "login_fail.png"),
  fullPage: true
}).catch(() => {});
require("fs").writeFileSync(
  require("path").resolve(__dirname, "login_fail.html"),
  await page.content()
);
await browser.close();
    throw new Error("globalSetup: Login baÅŸarÄ±sÄ±z. ADMIN_USER/ADMIN_PASS ve yetkileri kontrol edin.");
  }

  await context.storageState({ path: STATE });
  console.log("[setup] state exists:", fs.existsSync(STATE));

  await browser.close();
};