import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.BASE_URL ?? 'http://127.0.0.1:8010';

export default defineConfig({
  testDir: './tests',
  timeout: 30 * 1000,
  retries: 2,

  // ESM configte dÃ¼z string yol:
  globalSetup: './tests/global.setup.cjs',

  use: { actionTimeout: 10_000, navigationTimeout: 15_000,
    baseURL,
    storageState: 'storage/user.json',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    { name: 'chromium', use: { actionTimeout: 10_000, navigationTimeout: 15_000, ...devices['Desktop Chrome'] } },
    // { name: 'firefox', use: { actionTimeout: 10_000, navigationTimeout: 15_000, ...devices['Desktop Firefox'] } },
    // { name: 'webkit',  use: { actionTimeout: 10_000, navigationTimeout: 15_000, ...devices['Desktop Safari'] } },
  ],

  reporter: [
    ['line'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
  ],
});

