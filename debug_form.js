const { chromium } = require("playwright");

(async () => {
   const browser = await chromium.launch({ headless: false }); // Başlıklı modda çalışır
   const context = await browser.newContext({ storageState: "storage/user.json" });
   const page = await context.newPage();

   const urlToTest = "http://127.0.0.1:8010/admin/maintenance/equipment/add/";
   console.log("?? URL:", urlToTest);

   await page.goto(urlToTest);
   await page.waitForLoadState("networkidle");

   const finalUrl = page.url();
   console.log("?? Final URL:", finalUrl);

   // Tüm HTML'i kaydet
   const html = await page.content();
   require("fs").writeFileSync("debug_equipment_add.html", html, "utf8");
   console.log("? HTML kaydedildi: debug_equipment_add.html");

   // Screenshot al
   await page.screenshot({ path: "debug_equipment_add.png", fullPage: true });
   console.log("? Screenshot kaydedildi: debug_equipment_add.png");

   // Sayfa başlığını ve vücut metnini kontrol et
   console.log("?? Title:", await page.title());
   const bodyText = await page.locator("body").textContent();
   console.log("\n?? Body ilk 500 karakter:");
   console.log(bodyText.substring(0, 500));

   // Eğer sayfa yüklenmişse, formdaki ilk alanı kontrol et
   const nameInputCount = await page.locator("#id_name").count();
   console.log("?? #id_name Sayısı:", nameInputCount);

   // İsterseniz burada durdurup tarayıcıyı inceleyebilirsiniz:
   // await page.pause(); 
   await browser.close();
})();
