(venv) PS C:\dev\bakim_kalibrasyon> import { test as setup, expect } from "@playwright/test";
>>
>> // Oturum durumunun kaydedileceği dosya yolu
>> const authFile = "playwright/.auth/user.json";
>>
>> // Bu kurulum testi sadece bir kere çalışır ve oturum açma durumunu kaydeder.
>> setup("Oturum Açma Durumunu Kaydet", async ({ page }) => {
>>     console.log("-> Oturum açma işlemi başlatılıyor...");
>>
>>     // 1. Django Admin Login sayfasına git
>>     await page.goto("http://127.0.0.1:8010/admin/login/");
>>
>>     // 2. Oturum açma kimlik bilgilerini doldur
>>     await page.fill("#id_username", "admin");
>>     await page.fill("#id_password", "admin");
>>
>>     // 3. Login butonuna tıkla
>>     await page.click("input[type=submit]");
>>
>>     // Yönlendirmenin http://127.0.0.1:8010/admin/ adresine tamamlanmasını bekle
>>     // Oturum açma sorununuzu çözmek için bekleme süresini 30 saniyeye çıkardık.
>>     await page.waitForURL("http://127.0.0.1:8010/admin/", { timeout: 30000 });
>>
>>     // Başarılı giriş kontrolü (bu kez zaman aşımı hatası almamalıyız)
>>     await expect(page).toHaveURL("http://127.0.0.1:8010/admin/");
>>
>>     // 4. Oturum durumunu dosyaya kaydet
>>     await page.context().storageState({ path: authFile });
>>
>>     console.log(`-> Oturum durumu başarıyla kaydedildi: ${authFile}`);
>> });
>>
At line:7 char:37
+ setup("Oturum Açma Durumunu Kaydet", async ({ page }) => {
+                                     ~
Missing expression after ','.
At line:7 char:38
+ setup("Oturum Açma Durumunu Kaydet", async ({ page }) => {
+                                      ~~~~~
Unexpected token 'async' in expression or statement.
At line:7 char:37
+ setup("Oturum Açma Durumunu Kaydet", async ({ page }) => {
+                                     ~
Missing closing ')' in expression.
At line:28 char:24
+     await page.context().storageState({ path: authFile });
+                        ~
An expression was expected after '('.
At line:30 char:70
+ ...    console.log(`-> Oturum durumu başarıyla kaydedildi: ${authFile}`);
+                                                                         ~
Missing closing ')' in expression.
At line:31 char:2
+ });
+  ~
Unexpected token ')' in expression or statement.
    + CategoryInfo          : ParserError: (:) [], ParentContainsErrorRecordException
    + FullyQualifiedErrorId : MissingExpressionAfterToken

(venv) PS C:\dev\bakim_kalibrasyon>