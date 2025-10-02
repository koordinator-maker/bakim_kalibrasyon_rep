// reporters/quarantine-reporter.js (Karantina ve AI Kuyruk Yöneticisi)
const fs = require('fs');
const path = require('path');
const QUARANTINE_FILE = path.join(process.cwd(), 'quarantine.json');
const AI_QUEUE_FILE = path.join(process.cwd(), 'ai_queue', 'failed_tests.jsonl');

class QuarantineReporter {
    loadQuarantine() {/*...loading logic*/}
    onTestEnd(test, result) {
        const testId = test.title; 
        if (result.status === 'failed') {
            // Hata sayacını artır ve AI kuyruğuna yaz
            // ... (Karantina mantığı)
            const aiReport = { id: testId, status: 'failed', error: result.errors[0]?.message.split('\n')[0] || 'Tanımsız hata' };
            fs.appendFileSync(AI_QUEUE_FILE, JSON.stringify(aiReport) + '\n');
            if (this.quarantine[testId] >= 3) {
                console.log(`[KARANTİNA] Görev ${testId} 3. kez başarısız oldu ve karantinaya alındı.`);
            }
        } else if (result.status === 'passed' && this.quarantine[testId]) {/*... reset logic */}
    }
    onEnd(result) { console.log(`[RAPOR] Karantina ve AI kuyruğu güncellendi.`); }
}
module.exports = QuarantineReporter;
