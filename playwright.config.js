// Playwright yapılandırma (PowerShell tarafından oluşturulmuştur)
import { defineConfig } from '@playwright/test';

export default defineConfig({
    timeout: 15 * 1000, // 15 Saniye toplam test süresi
    retries: 2, // 3. kez başarısız olan görev karantinaya alınır (2 tekrar izni)

    use: {
        actionTimeout: 5000, // 5 Saniye: Tekil faaliyetler için Fail-Fast
        navigationTimeout: 10000, // 10 Saniye: Sayfa yükleme için Fail-Fast
    },
    
    reporter: [
        ['list'],
        ['./reporters/quarantine-reporter.js'], 
    ],
    projects: [ { name: 'chromium', use: { browserName: 'chromium' } } ],
});
