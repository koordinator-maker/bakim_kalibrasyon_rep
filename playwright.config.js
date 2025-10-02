// Playwright yapılandırma (PowerShell tarafından oluşturulmuştur)
import { defineConfig } from '@playwright/test';

// Oturum durumunun kaydedileceği yer (Basit string kullanımı, Playwright'ın kendisi çözer)
const storageStatePath = 'storage/user.json'; 

export default defineConfig({
     timeout: 15 * 1000,
     retries: 2,

     use: {
          baseURL: 'http://localhost:8000',
          actionTimeout: 5000,
          navigationTimeout: 10000,
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
               use: {
                    baseURL: 'http://localhost:8000',
                    // Setup projesinin kaydettiği yer:
                    storageState: storageStatePath, 
               },
          },
          // 2. Ana Test Projesi: Kurulumdan gelen oturum durumunu kullanır.
          {
               name: 'chromium',
               testIgnore: 'tests/_setup.spec.js', // Setup dosyasını hariç tut
               use: {
                    browserName: 'chromium',
                    // Aynı yolu kullanmak zorunludur:
                    storageState: storageStatePath, 
               },
               dependencies: ['setup'], // Setup'ın tamamlanmasını bekle
          },
     ],
});
