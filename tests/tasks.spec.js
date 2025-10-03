const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

// ============================================================
// RENKLI KONSOL ÇIKTISI
// ============================================================
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m',
};

// ============================================================
// SES KONTROLÜ - Ortam değişkeni ile açılıp kapatılabilir
// ============================================================
const BEEP_ENABLED = process.env.PLAYWRIGHT_BEEP !== "0";

function beep() { 
  if (!BEEP_ENABLED) return;
  try { process.stdout.write("\x07"); } catch {} 
}

// ============================================================
// GÖRSEL YARDIMCI FONKSİYONLAR
// ============================================================
function printBox(title, content, color = colors.cyan) {
  const width = 80;
  const border = '═'.repeat(width);
  console.log(`\n${color}╔${border}╗${colors.reset}`);
  console.log(`${color}║${title.padEnd(width)}║${colors.reset}`);
  console.log(`${color}╠${border}╣${colors.reset}`);
  content.forEach(line => {
    console.log(`${color}║${colors.reset} ${line.padEnd(width-2)} ${color}║${colors.reset}`);
  });
  console.log(`${color}╚${border}╝${colors.reset}\n`);
}

function printTestHeader(testId, title) {
  console.log(`\n${colors.bright}${colors.blue}${'▶'.repeat(40)}${colors.reset}`);
  console.log(`${colors.bright}${colors.blue}▶▶▶ TEST: ${testId} - ${title}${colors.reset}`);
  console.log(`${colors.bright}${colors.blue}${'▶'.repeat(40)}${colors.reset}\n`);
}

function printSuccess(message) {
  console.log(`${colors.green}✅ ${message}${colors.reset}`);
}

function printWarning(message) {
  console.log(`${colors.yellow}⚠️  ${message}${colors.reset}`);
}

function printError(message) {
  console.log(`${colors.red}❌ ${message}${colors.reset}`);
}

function printInfo(message) {
  console.log(`${colors.cyan}ℹ️  ${message}${colors.reset}`);
}

function printTaskRequirements(steps, designRef, threshold) {
  const width = 80;
  const border = '═'.repeat(width);
  console.log(`${colors.cyan}╔${border}╗${colors.reset}`);
  console.log(`${colors.cyan}║ ${colors.bright}İSTENENLER (GÖREV TANIMI)${colors.reset}${' '.repeat(width - 29)}${colors.cyan}║${colors.reset}`);
  console.log(`${colors.cyan}╠${border}╣${colors.reset}`);
  
  steps.forEach(step => {
    const cmdText = step.cmd.toUpperCase().padEnd(6);
    const line = `${colors.bright}${cmdText}${colors.reset}: ${step.val}`;
    const plainLine = `${cmdText}: ${step.val}`;
    const padding = width - plainLine.length - 1;
    console.log(`${colors.cyan}║ ${colors.reset}${line}${' '.repeat(Math.max(0, padding))}${colors.cyan}║${colors.reset}`);
  });

  const isVisualSkip = !designRef || designRef.toUpperCase() === "N/A";
  const visualStatus = isVisualSkip 
    ? `VISUAL: Atlandı (N/A)`
    : `VISUAL: ${designRef} (Eşik: ${(threshold * 100).toFixed(0)}%)`;
  
  const padding = width - visualStatus.length - 1;
  console.log(`${colors.cyan}║ ${colors.reset}${visualStatus}${' '.repeat(Math.max(0, padding))}${colors.cyan}║${colors.reset}`);
  console.log(`${colors.cyan}╚${border}╝${colors.reset}\n`);
}

// ============================================================
// TEST İSTATİSTİKLERİ
// ============================================================
const stats = {
  total: 0,
  passed: 0,
  failed: 0,
  skipped: 0,
  startTime: Date.now(),
  testResults: [],
};

const cycleNumber = parseInt(process.env.TEST_CYCLE || '1', 10);
printInfo(`Çalıştırılan Test Döngüsü: ${cycleNumber}`);

test.use({ storageState: "storage/user.json" });

// ============================================================
// YARDIMCI FONKSİYONLAR
// ============================================================
let PNG, pixelmatch;
const BASE = process.env.BASE_URL || "http://127.0.0.1:8010";

function loadTasks() {
  const rootJson = path.resolve("tasks.json");
  const buildJson = path.resolve("build", "tasks.json");
  
  function readJsonNoBOM(filePath) {
    let content = fs.readFileSync(filePath, "utf8");
    if (content.charCodeAt(0) === 0xFEFF) {
      content = content.slice(1);
    }
    return JSON.parse(content);
  }
  
  if (fs.existsSync(rootJson)) return readJsonNoBOM(rootJson);
  if (fs.existsSync(buildJson)) return readJsonNoBOM(buildJson);
  throw new Error("tasks.json bulunamadı");
}

function parseSteps(jobDef) {
  const steps = [];
  for (const raw of String(jobDef || "").split(";")) {
    const part = raw.trim();
    if (!part) continue;
    const m = part.match(/^(\w+)\s*:\s*(.+)$/);
    if (!m) {
      steps.push({ cmd: "note", val: part });
      continue;
    }
    steps.push({ cmd: m[1].toLowerCase(), val: m[2].trim().replace(/^"|"$/g, "") });
  }
  return steps;
}

function normalizeWords(s) {
  return String(s || "")
    .replace(/\d+/g, " ")
    .replace(/[^\p{L}\s]/gu, " ")
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);
}

function coverage90(actualText, expectedText) {
  const A = new Set(normalizeWords(actualText));
  const E = normalizeWords(expectedText);
  if (!E.length) return true;
  let hit = 0;
  for (const w of E) if (A.has(w)) hit++;
  return hit / E.length >= 0.9;
}

async function ensurePixelLibs() {
  if (!PNG || !pixelmatch) {
    try {
      PNG = require("pngjs").PNG;
      pixelmatch = require("pixelmatch");
    } catch (e) {
      printWarning("PNG/Pixelmatch kütüphaneleri yüklenemedi");
    }
  }
}

async function visualCompare(page, designRefPath, threshold = 0.85, id = "task") {
  await ensurePixelLibs();
  
  if (!PNG || !pixelmatch) {
    printWarning(`[VISUAL] ${id}: Kütüphaneler eksik → skip`);
    return;
  }
  
  const rawRef = (designRefPath ?? "").toString().trim();
  if (!rawRef || rawRef.toUpperCase() === "N/A") {
    printWarning(`[VISUAL] ${id}: design_ref N/A → skip`);
    return;
  }
  
  const refPath = path.resolve(rawRef);
  if (!fs.existsSync(refPath)) {
    printWarning(`[VISUAL] ${id}: reference not found → skip`);
    return;
  }
  
  const outDir = path.resolve("targets", "actual");
  fs.mkdirSync(outDir, { recursive: true });
  const actPath = path.join(outDir, `${id}.png`);
  await page.screenshot({ path: actPath, fullPage: true });
  
  const ref = PNG.sync.read(fs.readFileSync(refPath));
  const act = PNG.sync.read(fs.readFileSync(actPath));
  const w = Math.min(ref.width, act.width);
  const h = Math.min(ref.height, act.height);
  const refCrop = new PNG({ width: w, height: h });
  const actCrop = new PNG({ width: w, height: h });
  PNG.bitblt(ref, refCrop, 0, 0, 0, 0, w, h);
  PNG.bitblt(act, actCrop, 0, 0, 0, 0, w, h);
  
  const diff = new PNG({ width: w, height: h });
  const mismatch = pixelmatch(refCrop.data, actCrop.data, diff.data, w, h, { threshold: 0.1 });
  const similarity = 1 - mismatch / (w * h);
  
  printInfo(`[VISUAL] ${id}: Benzerlik ${(similarity * 100).toFixed(2)}%`);
  expect(similarity).toBeGreaterThanOrEqual(threshold);
}

// ============================================================
// TEST YUKLE VE BASLA
// ============================================================
const tasks = loadTasks();
if (!Array.isArray(tasks) || tasks.length === 0) {
  throw new Error("tasks.json boş");
}

stats.total = tasks.length;

test.beforeAll(() => {
  printBox('🚀 TEST SUITE BAŞLANGICI', [
    `Toplam Yüklenen Görev: ${stats.total}`,
    `Çalışan Test Döngüsü: ${cycleNumber}`,
    `Base URL: ${BASE}`,
    `Ses: ${BEEP_ENABLED ? 'AÇIK' : 'KAPALI'}`,
    `Başlangıç: ${new Date().toLocaleString('tr-TR')}`,
  ], colors.magenta);
});

for (const t of tasks) {
  test(`${t.id} - ${t.title}`, async ({ page }) => {
    const testStartTime = Date.now();
    printTestHeader(t.id, t.title);
    beep();
    
    const steps = parseSteps(t.job_definition);
    printTaskRequirements(steps, t.design_ref, t.visual_threshold);
    printInfo(`Adım Sayısı: ${steps.length}`);
    
    try {
      // 1) open
      const open = steps.find(s => s.cmd === "open");
      if (open) {
        const url = open.val.startsWith("http") ? open.val : BASE + open.val;
        printInfo(`Açılıyor: ${url}`);
        await page.goto(url, { waitUntil: "domcontentloaded" });
        printSuccess(`Sayfa yüklendi: ${page.url()}`);
      }
      
      // 2) expect
      for (const s of steps.filter(s => s.cmd === "expect")) {
        printInfo(`Bekleniyor: ${s.val}`);
        await expect(page.locator(s.val)).toBeVisible({ timeout: 3000 });
        printSuccess(`Element bulundu: ${s.val}`);
      }
      
      // 3) text
      const txt = steps.find(s => s.cmd === "text");
      if (txt) {
        printInfo(`Metin kontrolü: "${txt.val}"`);
        const body = await page.locator("body").innerText();
        const ok = coverage90(body, txt.val);
        expect(ok, "Metin kapsama < %90").toBeTruthy();
        printSuccess(`Metin kapsama: ≥90%`);
      }
      
      // 4) visual
      if (t.design_ref) {
        const thr = t.visual_threshold ?? 0.85;
        await visualCompare(page, t.design_ref, thr, t.id);
      }
      
      stats.passed++;
      stats.testResults.push({ 
        id: t.id, 
        status: 'PASSED', 
        error: null, 
        title: t.title, 
        duration: (Date.now() - testStartTime), 
        cycle: cycleNumber 
      });
      printSuccess(`✅ TEST BAŞARILI: ${t.id}`);
      
    } catch (error) {
      stats.failed++;
      stats.testResults.push({ 
        id: t.id, 
        status: 'FAILED', 
        error: error.message, 
        title: t.title, 
        duration: (Date.now() - testStartTime), 
        cycle: cycleNumber 
      });
      printError(`❌ TEST BAŞARISIZ: ${t.id}`);
      printError(`Hata: ${error.message}`);
      throw error;
    }
  });
}

test.afterAll(() => {
  const duration = ((Date.now() - stats.startTime) / 1000).toFixed(2);
  const passRate = ((stats.passed / stats.total) * 100).toFixed(2);
  
  // Karantina raporu
  const quarantineReport = ['ID | Başlık | Durum | Çözüldü/Döngü'];
  stats.testResults.forEach(r => {
    const statusColor = r.status === 'PASSED' ? colors.green : colors.red;
    const cycleInfo = r.status === 'PASSED' 
      ? `ÇÖZÜLDÜ (${r.cycle}. Döngü)` 
      : `BEKLEMEDE`;
    quarantineReport.push(`${r.id} | ${r.title} | ${statusColor}${r.status}${colors.reset} | ${cycleInfo}`);
  });
  
  printBox('📄 KARANTİNA RAPORU (GÖREV DURUM TAKİBİ)', quarantineReport, colors.yellow);
  
  // Özet rapor
  const summary = [
    `Toplam Yüklenen Görev: ${stats.total}`, 
    `Çalışan Test Döngüsü: ${cycleNumber}`,
    `Başarılı Görev: ${colors.green}${stats.passed}${colors.reset}`,
    `Başarısız Görev: ${colors.red}${stats.failed}${colors.reset}`,
    `Başarı Oranı: ${passRate}%`,
    `Toplam Süre: ${duration}s`,
    `Bitiş: ${new Date().toLocaleString('tr-TR')}`,
  ];
  
  if (stats.failed === 0) {
    printBox('✅ TÜM GÖREVLER BAŞARILI!', summary, colors.green);
  } else {
    printBox('⚠️  BAZI GÖREVLER BAŞARISIZ', summary, colors.yellow);
  }
  
  console.log(`${colors.cyan}--- TEST ORTAMI BİLGİSİ ---${colors.reset}`);
  console.log(`[3. HATA Notu]: Playwright'ın konsol çıktısındaki '3. Hata' veya 'Setup' hatası, bu görev raporu kapsamı dışındadır.`);
  console.log(`Bu rapor SADECE tasks.json'dan yüklenen ${stats.total} görevin durumunu gösterir.\n`);
});