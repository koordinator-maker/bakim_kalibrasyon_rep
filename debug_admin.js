const { chromium } = require("playwright");

(async () => {
   const browser = await chromium.launch({ headless: false }); // Başlıklı modda çalışır
   const context = await browser.newContext({ storageState: "storage/user.json" });
   const page = await context.newPage();

   const urlToTest = "http://127.0.0.1:8010/admin/"; // Kök Admin Sayfası
   console.log("?? URL:", urlToTest);

   await page.goto(urlToTest);
   await page.waitForLoadState("networkidle");

   console.log("?? Title:", await page.title());

   // Tüm HTML'i kaydet
   const html = await page.content();
   require("fs").writeFileSync("debug_admin_root.html", html, "utf8");
   console.log("✅ HTML kaydedildi: debug_admin_root.html");

   // Screenshot al
   await page.screenshot({ path: "debug_admin_root.png", fullPage: true });
   console.log("✅ Screenshot kaydedildi: debug_admin_root.png");

   // Sayfadaki tüm linkleri (URL'leri) bul ve yazdır
   console.log("\n?? Admin Sayfasındaki Tüm Linkler:");
   const links = await page.$$eval("a", anchors => anchors.map(a => a.href));
   
   // Sadece "/admin/" ile başlayanları filtrele
   const adminLinks = links.filter(link => link.includes('/admin/') && !link.endsWith('/admin/')).slice(0, 10);
   
   adminLinks.forEach(link => console.log(link));

   await browser.close();
})();
