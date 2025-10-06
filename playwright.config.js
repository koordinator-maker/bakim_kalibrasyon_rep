import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: 'tests',
  reporter: [['html', { open: 'never' }]],
  use: { baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010' },
  projects: [
    { name: 'setup', testMatch: /_setup\.spec\.js/ },
    {
      name: 'chromium',
      testIgnore: /_setup\.spec\.js/,
      use: { ...devices['Desktop Chrome'], storageState: 'storage/user.json' },
      dependencies: ['setup'],
    },
  ],
});