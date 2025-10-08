// Playwright yapÄ±landÄ±rma
import { defineConfig } from '@playwright/test';

// Oturum durumunun kaydedileceÄŸi yer
const storageStatePath = 'storage/user.json'; 

export default defineConfig({`n  globalSetup: require.resolve("./tests/ensure_tasks_json.cjs"),
     timeout: 30 * 1000, // Genel Test Zaman AÅŸÄ±mÄ± 30 saniye
     retries: 2,

     use: {
          baseURL: 'http://localhost:8000',
          actionTimeout: 5000,
          navigationTimeout: 30000, // Navigasyon Zaman AÅŸÄ±mÄ± 30 saniye
     },

     reporter: [
          ['list'],
          ['./reporters/quarantine-reporter.js'],
     ],

     // Projeleri tanÄ±mlama
     projects: [
          // 1. Kurulum Projesi: Oturum durumunu hazÄ±rlar.
          {
               name: 'setup',
               testMatch: 'tests/_setup.spec.js',
               timeout: 30 * 1000, // Kurulum projesi iÃ§in Ã¶zel 30 saniye
               use: {
                    baseURL: 'http://localhost:8000',
                    storageState: storageStatePath, 
               },
          },
          // 2. Ana Test Projesi: Kurulumdan gelen oturum durumunu kullanÄ±r.
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
