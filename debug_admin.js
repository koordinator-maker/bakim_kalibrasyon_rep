const { chromium } = require("playwright");

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({ storageState: "storage/user.json" });
  const page = await context.newPage();
  
  console.log("🔗 URL: http://127.0.0.1:8010/admin/");
  
  await page.goto("http://127.0.0.1:8010/admin/");
  await page.waitForLoadState("networkidle");
  
  const url = page.url();
  console.log("📍 Final URL:", url);
  
  const title = await page.title();
  console.log("📄 Title:", title);
  
  // Tüm HTML'i kaydet
  const html = await page.content();
  require("fs").writeFileSync("admin_full.html", html, "utf8");
  console.log("✅ HTML kaydedildi: admin_full.html");
  
  // Screenshot
  await page.screenshot({ path: "admin_full.png", fullPage: true });
  console.log("✅ Screenshot: admin_full.png");
  
  // Body metni
  const bodyText = await page.locator("body").textContent();
  console.log("\n📝 Body ilk 1000 karakter:");
  console.log(bodyText.substring(0, 1000));
  
  // Tüm selector'ları kontrol et
  const hasContent = await page.locator("#content").count();
  const hasBody = await page.locator("body").count();
  const hasDjangoAdmin = await page.locator(".django-admin").count();
  
  console.log("\n🔎 Element kontrolü:");
  console.log("  #content:", hasContent);
  console.log("  body:", hasBody);
  console.log("  .django-admin:", hasDjangoAdmin);
  
  await page.pause();
  await browser.close();
})();
