// Rev: 2025-10-02 12:20 r1
// auth.setup.js
const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

module.exports = async () => {
  const STORAGE_PATH = path.join(__dirname, 'storage', 'user.json');
  const baseURL = process.env.BASE_URL || 'http://127.0.0.1:8010';

  // storage klasörü garanti
  fs.mkdirSync(path.dirname(STORAGE_PATH), { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage();

  // LOGIN AKIŞI — kendi uygulamana göre selector/URL uyarlayabilirsin
  await page.goto(`${baseURL}/admin/login/`, { waitUntil: 'domcontentloaded' });
  await page.fill('#id_username', process.env.ADMIN_USER || 'hp');
  await page.fill('#id_password', process.env.ADMIN_PASS || 'admin');
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('text=/Log in|Giriş|Oturum Aç/i'),
  ]);

  // Oturum durumunu kaydet
  await page.context().storageState({ path: STORAGE_PATH });
  await browser.close();
};
