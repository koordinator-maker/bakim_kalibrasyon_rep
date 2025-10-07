const fs = require("fs");
const path = require("path");

class CustomJsonReporter {
  constructor(options = {}) {
    this.options = options;
    this.results = {
      stats: { total: 0, passed: 0, failed: 0, skipped: 0, startTime: null, endTime: null },
      tests: []
    };
    // Varsayılan çıktı yolu: targets/artifacts/results.json
    this.outFile = (options.outputFile && String(options.outputFile)) || "targets/artifacts/results.json";
  }

  onBegin(config, suite) {
    this.results.stats.startTime = new Date().toISOString();
    // Çıktı klasörünü garanti et
    const outDir = path.dirname(this.outFile);
    fs.mkdirSync(outDir, { recursive: true });
  }

  onTestEnd(test, result) {
    this.results.stats.total += 1;
    const status = result.status;
    if (status === "passed") this.results.stats.passed += 1;
    else if (status === "skipped") this.results.stats.skipped += 1;
    else this.results.stats.failed += 1;

    this.results.tests.push({
      title: test.title,
      location: test.location,
      project: test.parent?.project()?.name || null,
      status,
      duration_ms: result.duration,
      error: result.error ? {
        message: result.error.message,
        stack: result.error.stack
      } : null,
    });
  }

  async onEnd() {
    this.results.stats.endTime = new Date().toISOString();
    fs.writeFileSync(this.outFile, JSON.stringify(this.results, null, 2), "utf-8");
    // Konsola kısa bir özet de basalım
    const s = this.results.stats;
    console.log(`[custom-json] total=${s.total} passed=${s.passed} failed=${s.failed} skipped=${s.skipped}`);
    console.log(`[custom-json] file=${this.outFile}`);
  }
}

module.exports = CustomJsonReporter;
