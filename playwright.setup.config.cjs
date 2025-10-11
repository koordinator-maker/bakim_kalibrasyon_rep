/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: 'tests',
  testMatch: [/tests\/_setup.*\.(spec|test)\.(js|mjs|cjs|ts)$/i],
  testIgnore: ['**/tasks.spec.*'],
  reporter: [['line']],
  use: { baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010', headless: false }
};
module.exports = config;