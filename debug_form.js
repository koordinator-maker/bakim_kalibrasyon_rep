const { chromium } = require("playwright");

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({ storageState: "storage/user.json" });
  const page = await context.newPage();
  
  await page.goto("http://127.0.0.1:8010/admin/maintenance/equipment/add/");
  await page.waitForLoadState("networkidle");
  
  // Tüm input field'larını bul
  const inputs = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('input, select, textarea'))
      .map(el => ({
        tag: el.tagName,
        id: el.id,
        name: el.name,
        type: el.type,
        label: el.labels?.[0]?.textContent?.trim() || ''
      }));
  });
  
  console.log("\n📋 Form Field'ları:");
  console.table(inputs);
  
  // Screenshot
  await page.screenshot({ path: "equipment_form_debug.png", fullPage: true });
  console.log("\n✅ Screenshot: equipment_form_debug.png");
  
  await browser.close();
})();
