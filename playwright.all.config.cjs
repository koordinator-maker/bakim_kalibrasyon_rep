/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: 'tests',
  reporter: [
    ['line'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }]
  ],
  use: { baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010', headless: false, trace: 'on' }
};
module.exports = config;