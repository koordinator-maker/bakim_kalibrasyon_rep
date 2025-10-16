import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  timeout: 60000,
  
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010',
    storageState: 'storage/user.json',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
    trace: 'on-first-retry',
    headless: false,
  },
  
  retries: 2,
  
  globalSetup: './tests/_setup.spec.js',
});
