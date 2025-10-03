// Dosya: reporters/custom_json_reporter.js

const fs = require('fs');
const path = require('path');

// Test sonuçlarının kaydedileceği hedef klasör
const RESULTS_DIR = path.join(process.cwd(), 'targets', 'results');

class CustomJsonReporter {
  constructor(options) {
    this.options = options;
    // Raporlayıcı başlatıldığında hedef klasörün var olduğundan emin olunur.
    if (!fs.existsSync(RESULTS_DIR)) {
      fs.mkdirSync(RESULTS_DIR, { recursive: true });
    }
    console.log(`[Reporter] Sonuçlar şu klasöre yazılacak: ${RESULTS_DIR}`);
  }

  // Playwright tüm test koşusu bittiğinde bu metodu çağırır.
  onEnd(result) {
    // Sonuçların genel başarısızlık durumunu kontrol et
    const overallSuccess = result.status === 'passed';
    
    // Playwright test koşusu sonucu.
    const runSummary = {
        status: result.status,
        passed: overallSuccess,
        startTime: result.startTime,
        duration: result.duration
    };
    
    // run_summary.json dosyasına genel koşu özetini yaz
    const summaryFilePath = path.join(RESULTS_DIR, 'run_summary.json');
    fs.writeFileSync(summaryFilePath, JSON.stringify(runSummary, null, 2));

    // Testlerin ayrıntılı sonuçlarını döngüye al
    for (const suite of result.suites) {
      this.processSuite(suite);
    }
  }
  
  // Test gruplarını (suite) ve alt testleri işlemek için yardımcı metod
  processSuite(suite) {
    for (const test of suite.tests) {
      this.processTest(test);
    }
    for (const childSuite of suite.suites) {
      this.processSuite(childSuite);
    }
  }
  
  // Tek bir testin sonucunu işlemek için metod
  processTest(test) {
    const testStatus = test.outcome();
    const testTitle = test.title;
    
    // Her bir test sonucu için tek bir dosya oluştur (AI kuyruğu için lazım olacak)
    const fileName = `${testTitle.replace(/[^a-z0-9]/gi, '_')}.json`;
    const filePath = path.join(RESULTS_DIR, fileName);

    let failReason = null;
    let duration = 0;
    
    // Eğer test başarısız olduysa, hata detaylarını al
    if (testStatus !== 'expected') {
        const lastStep = test.results[test.results.length - 1];
        if (lastStep && lastStep.error) {
            failReason = lastStep.error.message || lastStep.error.stack || 'Bilinmeyen hata.';
        }
        duration = lastStep ? lastStep.duration : 0;
    } else {
        // Başarılı testin süresini al
        duration = test.results[test.results.length - 1].duration;
    }

    // Sonuç yapısı (PowerShell'in okuyacağı format)
    const testResult = {
        ok: testStatus === 'expected',
        status: testStatus,
        reason: failReason,
        duration: duration,
        // AI'ın analiz edebileceği ek metrikler buraya eklenebilir
        metrics: {
            steps: test.results.length > 0 ? test.results[test.results.length - 1].steps.map(s => s.title) : []
        }
    };

    fs.writeFileSync(filePath, JSON.stringify(testResult, null, 2));
    
    // Eğer test başarısızsa terminale ekstra uyarı yaz
    if (testResult.ok === false) {
      console.log(`[FAIL] ${testTitle} sonuç dosyası yazıldı: ${filePath}`);
    }
  }
}

module.exports = CustomJsonReporter;
