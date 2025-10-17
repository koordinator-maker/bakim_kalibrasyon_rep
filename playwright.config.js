import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  timeout: 90000,
  
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8010',
    storageState: 'storage/user.json',
    screenshot: 'on',
    video: 'on',
    trace: 'on',
    
    headless: false,           // PENCERE AÇIK!
    slowMo: 1000,              // Her hareket 1 saniye bekle
    
    viewport: { width: 1280, height: 720 },
  },
  
  retries: 0,  // Hızlı fail için
  workers: 1,  // Tek pencere
  
  globalSetup: './tests/_setup.spec.js',
});
