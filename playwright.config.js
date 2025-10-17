import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  timeout: 30000,
  
  use: {
    baseURL: 'http://127.0.0.1:8010',
    screenshot: 'on',
    video: 'on',
    trace: 'on',
    headless: false,
    slowMo: 1000,
  },
  
  retries: 0,
  workers: 1,
});
