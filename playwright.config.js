import { test as setup, expect } from '@playwright/test';

// Bu script, oturum açma işlemini gerçekleştirir ve oturum durumunu kaydeder.

// Django admin oturum açma bilgileri
// Lütfen bunları kendi geçerli admin kullanıcı adınız ve şifrenizle değiştirin.
const ADMIN_USER = 'admin'; 
const ADMIN_PASSWORD = 'test_password'; 
const authFile = 'playwright/.auth/user.json'; // Oturum durumunun kaydedileceği dosya yolu

setup('authenticate', async ({ page }) => {
  console.log('--- Playwright Setup: Oturum Açma Başlatılıyor ---');

  // Giriş sayfasına git
  await page.goto('http://127.0.0.1:8010/admin/login/');

  // Kullanıcı adı ve şifre alanlarını doldur
  await page.locator('#id_username').fill(ADMIN_USER);
  await page.locator('#id_password').fill(ADMIN_PASSWORD);

  // Giriş butonuna tıkla
  await page.locator('input[type=submit]').click();

  // KONTROL: Başarılı giriş yaptığımızdan emin olalım (Admin anasayfasına yönlendik mi?)
  // Playwright, anasayfa URL'ini kontrol edecektir.
  await expect(page).toHaveURL(/http:\/\/127\.0\.0\.1:8010\/admin\/$/);

  // Oturum durumunu kaydet (Bu dosya, diğer testleriniz tarafından kullanılacaktır)
  await page.context().storageState({ path: authFile });
  console.log(`--- Oturum Durumu Başarıyla Kaydedildi: ${authFile} ---`);
});
