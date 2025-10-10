/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: 'tests',
  // spec adlarını garanti altına alalım:
  testMatch: /.*\.(spec|test)\.(js|cjs|mjs|ts)/,
  reporter: [['line'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010',
    headless: false,
    trace: 'on'
  },
};
module.exports = config;