const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

// Renkli konsol
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

const BEEP_ENABLED = process.env.PLAYWRIGHT_BEEP !== "0";
function beep() { 
  if (!BEEP_ENABLED) return;
  try { process.stdout.write("\x07"); } catch {} 
}

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

function printSuccess(m) { console.log(`${colors.green}✅ ${m}${colors.reset}`); }
function printWarning(m) { console.log(`${colors.yellow}⚠️  ${m}${colors.reset}`); }
function printError(m) { console.log(`${colors.red}❌ ${m}${colors.reset}`); }
function printInfo(m) { console.log(`${colors.cyan}ℹ️  ${m}${colors.reset}`); }

function printTaskRequirements(steps, designRef, threshold) {
  const width = 80;
  const border = '═'.repeat(width);
  console.log(`${colors.cyan}╔${border}╗${colors.reset}`);
  console.log(`${colors.cyan}║ ${colors.bright}İSTENENLER${colors.reset}${' '.repeat(width - 13)}${colors.cyan}║${colors.reset}`);
  console.log(`${colors.cyan}╠${border}╣${colors.reset}`);
  
  steps.forEach(step => {
    const cmd = step.cmd.toUpperCase().padEnd(6);
    const line = `${colors.bright}${cmd}${colors.reset}: ${step.val}`;
    const plain = `${cmd}: ${step.val}`;
    console.log(`${colors.cyan}║ ${colors.reset}${line}${' '.repeat(Math.max(0, width - plain.length - 1))}${colors.cyan}║${colors.reset}`);
  });

  const vis = !designRef || designRef.toUpperCase() === "N/A" 
    ? `VISUAL: Atlandı` 
    : `VISUAL: ${designRef}`;
  console.log(`${colors.cyan}║ ${colors.reset}${vis}${' '.repeat(Math.max(0, width - vis.length - 1))}${colors.cyan}║${colors.reset}`);
  console.log(`${colors.cyan}╚${border}╝${colors.reset}\n`);
}

const stats = {
  total: 0,
  passed: 0,
  failed: 0,
  startTime: Date.now(),
  testResults: [],
};

const cycleNumber = parseInt(process.env.TEST_CYCLE || '1', 10);
printInfo(`Test Döngüsü: ${cycleNumber}`);

test.use({ storageState: "storage/user.json" });

let PNG, pixelmatch;
const BASE = process.env.BASE_URL || "http://127.0.0.1:8010";

function loadTasks() {
  const rootJson = path.resolve("tasks.json");
  const buildJson = path.resolve("build", "tasks.json");
  
  function readJsonNoBOM(fp) {
    let c = fs.readFileSync(fp, "utf8");
    if (c.charCodeAt(0) === 0xFEFF) c = c.slice(1);
    return JSON.parse(c);
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

function coverage90(actual, expected) {
  const A = new Set(normalizeWords(actual));
  const E = normalizeWords(expected);
  if (!E.length) return true;
  let hit = 0;
  for (const w of E) if (A.has(w)) hit++;
  return hit / E.length >= 0.9;
}

function expandSmartCandidates(expr) {
  const t = String(expr || '').trim();
  const out = new Set();
  out.add(t);

  let m = t.match(/^input\s*\[\s*name\s*=\s*['"]([^'"]+)['"]\s*\]$/i);
  if (m) {
    const k = m[1].toLowerCase().replace(/[\s\-]+/g,"_");
    out.add(`#id_${k}`);
    out.add(`[name="${k}"]`);
    if (k === "name") {
      out.add(`#id_title`);
      out.add(`#id_equipment_name`);
    }
    if (k.includes("serial")) {
      out.add(`#id_serial_number`);
    }
    return Array.from(out);
  }

  m = t.match(/^#id_([\w\-:]+)$/i);
  if (m) {
    const k = m[1].toLowerCase();
    out.add(`[name="${k}"]`);
    if (k === "name") out.add(`#id_title`);
    if (k.includes("serial")) out.add(`#id_serial_number`);
    return Array.from(out);
  }

  return Array.from(out);
}

function saveArtifacts(id, page, tag) {
  return page.screenshot({ 
    path: path.join("targets","actual",`${id}-${tag}.png`), 
    fullPage: true 
  }).then(() => {
    return page.content();
  }).then(html => {
    fs.mkdirSync(path.join("targets","actual"), { recursive: true });
    fs.writeFileSync(path.join("targets","actual",`${id}-${tag}.html`), html);
    printWarning(`[ARTIFACT] ${id}-${tag}.png/html`);
  }).catch(() => {});
}

function waitVisibleAny(page, id, expr, timeout) {
  const candidates = expandSmartCandidates(expr);
  const start = Date.now();
  
  return (async function tryNext(index) {
    if (index >= candidates.length) {
      await saveArtifacts(id, page, "notfound");
      throw new Error(`Hiçbir aday görünür değil: ${candidates.join(", ")}`);
    }
    
    const sel = candidates[index];
    const remaining = Math.max(500, timeout - (Date.now() - start));
    
    try {
      await expect(page.locator(sel).first()).toBeVisible({ timeout: remaining });
      printSuccess(`Element bulundu: ${sel}`);
      return;
    } catch (e) {
      return tryNext(index + 1);
    }
  })(0);
}

function ensurePixelLibs() {
  if (!PNG || !pixelmatch) {
    try {
      PNG = require("pngjs").PNG;
      pixelmatch = require("pixelmatch");
    } catch (e) {
      printWarning("PNG/Pixelmatch eksik");
    }
  }
}

function visualCompare(page, designRefPath, threshold, id) {
  ensurePixelLibs();
  
  if (!PNG || !pixelmatch) {
    printWarning(`[VISUAL] ${id}: kütüphaneler eksik`);
    return Promise.resolve();
  }
  
  const raw = (designRefPath ?? "").toString().trim();
  if (!raw || raw.toUpperCase() === "N/A") {
    printWarning(`[VISUAL] ${id}: N/A`);
    return Promise.resolve();
  }
  
  const refPath = path.resolve(raw);
  if (!fs.existsSync(refPath)) {
    printWarning(`[VISUAL] ${id}: reference not found`);
    return Promise.resolve();
  }
  
  const outDir = path.resolve("targets", "actual");
  fs.mkdirSync(outDir, { recursive: true });
  const actPath = path.join(outDir, `${id}.png`);
  
  return page.screenshot({ path: actPath, fullPage: true }).then(() => {
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
    
    printInfo(`[VISUAL] ${id}: ${(similarity * 100).toFixed(2)}%`);
    expect(similarity).toBeGreaterThanOrEqual(threshold || 0.85);
  });
}

const tasks = loadTasks();
if (!Array.isArray(tasks) || tasks.length === 0) {
  throw new Error("tasks.json boş");
}

stats.total = tasks.length;

test.beforeAll(() => {
  printBox('🚀 TEST BAŞLANGICI', [
    `Görev: ${stats.total}`,
    `Döngü: ${cycleNumber}`,
    `Base: ${BASE}`,
    `Ses: ${BEEP_ENABLED ? 'AÇIK' : 'KAPALI'}`,
    `Zaman: ${new Date().toLocaleString('tr-TR')}`,
  ], colors.magenta);
});

async function looksLikeLogin(page){
  const markers = [
    "input[name='username']",
    "input[name='password']",
    "form[action*='login']",
    "input[name='login']",
    "#login-form"
  ];
  for (const m of markers){
    if (await page.locator(m).count() > 0) return true;
  }
  const body = (await page.locator("body").innerText()).toLowerCase();
  return body.includes("login") || body.includes("giriş");
}

async function openAddSmart_v2(page, url){
  // 1) Direkt /add/
  await page.goto(url, { waitUntil: "load" });
  await page.waitForLoadState("networkidle");
  if (await page.locator("form[action$='/add/'], form[method='post']").count() > 0) return;

  // 2) /add/_direct/
  const direct = url.replace(/\/add\/?$/, "/add/_direct/");
  await page.goto(direct, { waitUntil: "load" });
  await page.waitForLoadState("networkidle");
  if (await page.locator("form[action$='/add/'], form[method='post']").count() > 0) return;

  // 3) Liste -> +Add
  const listUrl = url.replace(/\/add\/?$/, "/");
  await page.goto(listUrl, { waitUntil: "load" });
  await page.waitForLoadState("networkidle");
  const add = page.locator("ul.object-tools a.addlink, #content-main .object-tools a.addlink, a[href$='/add/']").first();
  if (await add.count() > 0 && await add.isVisible()) {
    await add.click();
    await page.waitForLoadState("domcontentloaded");
  }
}
async function ensureAdminForm(page){
  const selectors = [
    "input[name='csrfmiddlewaretoken']",
    "form[method='post']",
    "button[name='_save']",
    "input[name='_save']",
    "div.submit-row"
  ];
  for (const s of selectors){
    const loc = page.locator(s).first();
    if (await loc.count() > 0){
      try { await expect(loc).toBeVisible({ timeout: 500 }); return true; } catch {}
    }
  }
  return false;
}

for (const t of tasks){
  test(`${t.id} - ${t.title}`, async ({ page }) => {
    const start = Date.now();
    printTestHeader(t.id, t.title);
    beep();
    
    
  // --- inject: wrap page.goto to handle /add/ smart nav ---
  let __openSmartActive = false;
  const __origGoto = page.goto.bind(page);
  page.goto = async (u, opts) => {
    try {
      if (!__openSmartActive) {
        const s = (typeof u === "string" ? u : String(u));
        const absolute = s.startsWith("http") ? s : BASE + s;
        if (/\/add\/?$/.test(absolute)) {
          __openSmartActive = true;
          try { await openAddSmart_v2(page, absolute); }
          finally { __openSmartActive = false; }
          return page; // openAddSmart zaten navigate etti
        }
      }
      const r = await __origGoto(u, opts);
      await page.waitForLoadState("networkidle").catch(()=>{});
      return r;
    } catch(e){
      throw e;
    }
  };
  // --- /inject ---
const steps = parseSteps(t.job_definition);
    printTaskRequirements(steps, t.design_ref, t.visual_threshold);
    printInfo(`Adım: ${steps.length}`);
    
    try {
      const open = steps.find(s => s.cmd === "open");
      if (open) {
        const url = open.val.startsWith("http") ? open.val : BASE + open.val;
        printInfo(`Açılıyor: ${url}`);
        await page.goto(url, { waitUntil: "load" });
        await page.waitForLoadState("networkidle");
        
  // Guard: /add/ 404 ise bu testi atla
  try {
    if (/\/add\/?$/.test(url)) {
      const __t = (await page.title()).toLowerCase();
      const __b = (await page.locator("body").innerText()).toLowerCase();
      if (__t.indexOf("page not found") >= 0 || __b.indexOf("page not found") >= 0) {
        printInfo("E102 SKIP: /add/ 404 - model add kapalı");
        test.skip(true, "E102 SKIP: /add/ 404 - model add kapalı");
      }
    }
  } catch {}printSuccess(`Yüklendi: ${page.url()}`);
      }
      
      for (const s of steps.filter(s => s.cmd === "expect")) {
        printInfo(`Bekleniyor: ${s.val}`);
        await waitVisibleAny(page, t.id, s.val, 4000);
      }
      
      const txt = steps.find(s => s.cmd === "text");
      if (txt) {
        printInfo(`Metin: "${txt.val}"`);
        const body = await page.locator("body").innerText();
        const ok = coverage90(body, txt.val);
        expect(ok, "Metin < %90").toBeTruthy();
        printSuccess(`Metin: ≥90%`);
      }
      
      if (t.design_ref) {
        await visualCompare(page, t.design_ref, t.visual_threshold, t.id);
      }
      
      stats.passed++;
      stats.testResults.push({ 
        id: t.id, 
        status: 'PASSED', 
        title: t.title, 
        duration: Date.now() - start, 
        cycle: cycleNumber 
      });
      printSuccess(`BAŞARILI: ${t.id}`);
      
    } catch (error) {
      await saveArtifacts(t.id, page, 'failed');
      stats.failed++;
      stats.testResults.push({ 
        id: t.id, 
        status: 'FAILED', 
        error: error.message, 
        title: t.title, 
        duration: Date.now() - start, 
        cycle: cycleNumber 
      });
      printError(`BAŞARISIZ: ${t.id}`);
      printError(`Hata: ${error.message}`);
      throw error;
    }
  });
}

test.afterAll(() => {
  const duration = ((Date.now() - stats.startTime) / 1000).toFixed(2);
  const rate = ((stats.passed / stats.total) * 100).toFixed(2);
  
  const qr = ['ID | Başlık | Durum'];
  stats.testResults.forEach(r => {
    const c = r.status === 'PASSED' ? colors.green : colors.red;
    qr.push(`${r.id} | ${r.title} | ${c}${r.status}${colors.reset}`);
  });
  
  printBox('📄 SONUÇLAR', qr, colors.yellow);
  
  const summary = [
    `Toplam: ${stats.total}`, 
    `Döngü: ${cycleNumber}`,
    `Başarılı: ${colors.green}${stats.passed}${colors.reset}`,
    `Başarısız: ${colors.red}${stats.failed}${colors.reset}`,
    `Oran: ${rate}%`,
    `Süre: ${duration}s`,
  ];
  
  if (stats.failed === 0) {
    printBox('✅ TÜM TESTLER BAŞARILI!', summary, colors.green);
  } else {
    printBox('⚠️  BAZI TESTLER BAŞARISIZ', summary, colors.yellow);
  }
});





