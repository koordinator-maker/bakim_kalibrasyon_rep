/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: 'tests',
  testMatch: [
    /tests\/e\d{3}.*\.(spec|test)\.(js|mjs|cjs|ts)$/i,
    /tests\/EQP-.*\.(spec|test)\.(js|mjs|cjs|ts)$/
  ],
  // "tasks.json boş" fırlatan dosyayı tamamen hariç tut
  testIgnore: ['**/tasks.spec.*'],
  reporter: [['line'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010',
    headless: false,
    trace: 'on'
  },
};
module.exports = config;