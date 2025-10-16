import { chromium, FullConfig } from "@playwright/test";

async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;
  
  console.log("=== Global Setup: Creating admin login session ===");
  
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  // Admin login sayfasına git
  await page.goto(`${baseURL}/admin/`, { waitUntil: 'domcontentloaded' });
  console.log("Admin login page loaded");

  // Kullanıcı adı ve şifre
  await page.locator('input[name="username"]').fill(process.env.ADMIN_USER || "admin");
  await page.locator('input[name="password"]').fill(process.env.ADMIN_PASS || "admin123!");
  console.log("Credentials filled, submitting...");

  // Login submit - YENİ API
  await page.locator('input[type="submit"], button[type="submit"]').click();
  
  // URL değişene kadar bekle
  await page.waitForURL('**/admin/**', { timeout: 20000 });
  
  // Sayfa yüklenene kadar bekle
  await page.waitForLoadState('domcontentloaded');
  
  console.log("Login successful, URL:", page.url());

  // Storage'ı kaydet
  await context.storageState({ path: "storage/user.json" });
  console.log("Session saved to storage/user.json");
  
  await browser.close();
}

export default globalSetup;