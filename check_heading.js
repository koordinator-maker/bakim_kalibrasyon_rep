const { chromium } = require("playwright");

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({ storageState: "storage/user.json" });
  const page = await context.newPage();
  
  await page.goto("http://127.0.0.1:8010/admin/maintenance/equipment/");
  await page.waitForLoadState("networkidle");
  
  // Tüm h1'leri bul
  const h1Texts = await page.locator("h1").allTextContents();
  console.log("📌 Sayfadaki H1 başlıklar:", h1Texts);
  
  // Tüm başlıkları bul
  const allHeadings = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('h1, h2, h3'))
      .map(el => ({ tag: el.tagName, text: el.textContent.trim() }));
  });
  console.log("📋 Tüm başlıklar:", allHeadings);
  
  await page.screenshot({ path: "equipment_page.png", fullPage: true });
  console.log("✅ Screenshot: equipment_page.png");
  
  await browser.close();
})();
