import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  timeout: 60000,
  
  use: {
    baseURL: 'http://127.0.0.1:8010',
    storageState: 'storage/user.json',
    screenshot: 'on',
    video: 'on',
    trace: 'on',
    headless: false,
    slowMo: 2000,
    launchOptions: {
      slowMo: 2000
    }
  },
  
  retries: 1,
  workers: 1,
  globalSetup: './tests/_setup.spec.js',
});
