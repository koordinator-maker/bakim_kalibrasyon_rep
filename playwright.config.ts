import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  globalSetup: './global-setup.ts',
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010',
    storageState: 'storage/user.json',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
    trace: 'on-first-retry',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});