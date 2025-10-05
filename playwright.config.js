/** @type {import('@playwright/test').PlaywrightTestConfig} */
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010',
    headless: true,
    trace: 'on-first-retry',
  },
  projects: [
    // 1) Kurulum: login olup storage state YAZAR (storageState burada YOK!)
    {
      name: 'setup',
      testMatch: /.*_setup\.spec\.[jt]s/,
    },
    // 2) Asıl testler: storageState KULLANIR; önce 'setup' koşar
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'storage/user.json',
      },
      dependencies: ['setup'],
    },
  ],
});
