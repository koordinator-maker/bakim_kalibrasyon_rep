// Playwright yapılandırma
import { defineConfig } from '@playwright/test';

// Oturum durumunun kaydedileceği yer
const storageStatePath = 'storage/user.json'; 

export default defineConfig({
     timeout: 30 * 1000, // Genel Test Zaman Aşımı 30 saniye
     retries: 2,

     use: {
          baseURL: 'http://localhost:8000',
          actionTimeout: 5000,
          navigationTimeout: 30000, // Navigasyon Zaman Aşımı 30 saniye
     },

     reporter: [
          ['list'],
          ['./reporters/quarantine-reporter.js'],
     ],

     // Projeleri tanımlama
     projects: [
          // 1. Kurulum Projesi: Oturum durumunu hazırlar.
          {
               name: 'setup',
               testMatch: 'tests/_setup.spec.js',
               timeout: 30 * 1000, // Kurulum projesi için özel 30 saniye
               use: {
                    baseURL: 'http://localhost:8000',
                    storageState: storageStatePath, 
               },
          },
          // 2. Ana Test Projesi: Kurulumdan gelen oturum durumunu kullanır.
          {
               name: 'chromium',
               testIgnore: 'tests/_setup.spec.js', 
               use: {
                    browserName: 'chromium',
                    storageState: storageStatePath, 
               },
               dependencies: ['setup'], 
          },
     ],
});
