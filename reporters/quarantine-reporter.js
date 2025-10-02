// reporters/quarantine-reporter.js (Karantina ve AI Kuyruk Yöneticisi - TAM İMPLEMENTASYON)
const fs = require('fs');
const path = require('path');

const QUARANTINE_FILE = path.join(process.cwd(), 'quarantine.json');
const AI_QUEUE_FILE = path.join(process.cwd(), 'ai_queue', 'failed_tests.jsonl');

class QuarantineReporter {
     constructor(options) {
          this.quarantine = {};
          this.loadQuarantine();
     }

     loadQuarantine() {
          if (fs.existsSync(QUARANTINE_FILE)) {
               try {
                    this.quarantine = JSON.parse(fs.readFileSync(QUARANTINE_FILE, 'utf8'));
                    console.log(`[REPORTER] Karantina durumu yüklendi: ${Object.keys(this.quarantine).length} öğe.`);
               } catch (e) {
                    console.error('[REPORTER HATA] Karantina dosyasını okurken hata oluştu, sıfırdan başlatılıyor.', e.message);
                    this.quarantine = {};
               }
          }
     }

     onTestEnd(test, result) {
          const testId = `${path.basename(test.location.file)} - ${test.title}`;

          if (result.status === 'failed' || result.status === 'timedOut') {
               this.quarantine[testId] = (this.quarantine[testId] || 0) + 1;

               const errorMsg = result.errors[0]?.message || result.error?.message || 'Tanımsız veya süre aşımı hatası';
               const aiReport = {
                    id: testId,
                    status: result.status,
                    error: errorMsg.split('\n')[0],
                    timestamp: new Date().toISOString()
               };
               fs.appendFileSync(AI_QUEUE_FILE, JSON.stringify(aiReport) + '\n');

               if (this.quarantine[testId] >= 3) {
                    console.log(`[KARANTİNA] Görev ${testId} 3. kez başarısız oldu ve karantinaya alındı.`);
               }
          } else if (result.status === 'passed' && this.quarantine[testId] && this.quarantine[testId] < 3) {
               delete this.quarantine[testId];
          }
     }

     onEnd(result) {
          fs.writeFileSync(QUARANTINE_FILE, JSON.stringify(this.quarantine, null, 2));
          console.log(`[RAPOR] Karantina durumu güncellendi. Başarısızlık sayısı: ${result.failures}.`);
     }
}

module.exports = QuarantineReporter;
