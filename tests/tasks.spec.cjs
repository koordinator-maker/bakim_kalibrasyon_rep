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
  const border = 'Ã¢â€¢Â'.repeat(width);
  console.log(`\n${color}Ã¢â€¢â€${border}Ã¢â€¢â€”${colors.reset}`);
  console.log(`${color}Ã¢â€¢â€˜${title.padEnd(width)}Ã¢â€¢â€˜${colors.reset}`);
  console.log(`${color}Ã¢â€¢Â ${border}Ã¢â€¢Â£${colors.reset}`);
  content.forEach(line => {
    console.log(`${color}Ã¢â€¢â€˜${colors.reset} ${line.padEnd(width-2)} ${color}Ã¢â€¢â€˜${colors.reset}`);
  });
  console.log(`${color}Ã¢â€¢Å¡${border}Ã¢â€¢Â${colors.reset}\n`);
}

function printTestHeader(testId, title) {
  console.log(`\n${colors.bright}${colors.blue}${'Ã¢â€“Â¶'.repeat(40)}${colors.reset}`);
  console.log(`${colors.bright}${colors.blue}Ã¢â€“Â¶Ã¢â€“Â¶Ã¢â€“Â¶ TEST: ${testId} - ${title}${colors.reset}`);
  console.log(`${colors.bright}${colors.blue}${'Ã¢â€“Â¶'.repeat(40)}${colors.reset}\n`);
}

function printSuccess(m) { console.log(`${colors.green}Ã¢Å“â€¦ ${m}${colors.reset}`); }
function printWarning(m) { console.log(`${colors.yellow}Ã¢Å¡Â Ã¯Â¸Â  ${m}${colors.reset}`); }
function printError(m) { console.log(`${colors.red}Ã¢ÂÅ’ ${m}${colors.reset}`); }
function printInfo(m) { console.log(`${colors.cyan}Ã¢â€Â¹Ã¯Â¸Â  ${m}${colors.reset}`); }

function printTaskRequirements(steps, designRef, threshold) {
  const width = 80;
  const border = 'Ã¢â€¢Â'.repeat(width);
  console.log(`${colors.cyan}Ã¢â€¢â€${border}Ã¢â€¢â€”${colors.reset}`);
  console.log(`${colors.cyan}Ã¢â€¢â€˜ ${colors.bright}Ã„Â°STENENLER${colors.reset}${' '.repeat(width - 13)}${colors.cyan}Ã¢â€¢â€˜${colors.reset}`);
  console.log(`${colors.cyan}Ã¢â€¢Â ${border}Ã¢â€¢Â£${colors.reset}`);
  
  steps.forEach(step => {
    const cmd = step.cmd.toUpperCase().padEnd(6);
    const line = `${colors.bright}${cmd}${colors.reset}: ${step.val}`;
    const plain = `${cmd}: ${step.val}`;
    console.log(`${colors.cyan}Ã¢â€¢â€˜ ${colors.reset}${line}${' '.repeat(Math.max(0, width - plain.length - 1))}${colors.cyan}Ã¢â€¢â€˜${colors.reset}`);
  });

  const vis = !designRef || designRef.toUpperCase() === "N/A" 
    ? `VISUAL: AtlandÃ„Â±` 
    : `VISUAL: ${designRef}`;
  console.log(`${colors.cyan}Ã¢â€¢â€˜ ${colors.reset}${vis}${' '.repeat(Math.max(0, width - vis.length - 1))}${colors.cyan}Ã¢â€¢â€˜${colors.reset}`);
  console.log(`${colors.cyan}Ã¢â€¢Å¡${border}Ã¢â€¢Â${colors.reset}\n`);
}

const stats = {
  total: 0,
  passed: 0,
  failed: 0,
  startTime: Date.now(),
  testResults: [],
};

const cycleNumber = parseInt(process.env.TEST_CYCLE || '1', 10);
printInfo(`Test DÃƒÂ¶ngÃƒÂ¼sÃƒÂ¼: ${cycleNumber}`);

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
  throw new Error("tasks.json bulunamadÃ„Â±");
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
      throw new Error(`HiÃƒÂ§bir aday gÃƒÂ¶rÃƒÂ¼nÃƒÂ¼r deÃ„Å¸il: ${candidates.join(", ")}`);
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
    printWarning(`[VISUAL] ${id}: kÃƒÂ¼tÃƒÂ¼phaneler eksik`);
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
  throw new Error("tasks.json boÃ…Å¸");
}

stats.total = tasks.length;

test.beforeAll(() => {
  printBox('ÄŸÅ¸Å¡â‚¬ TEST BAÃ…ÂLANGICI', [
    `GÃƒÂ¶rev: ${stats.total}`,
    `DÃƒÂ¶ngÃƒÂ¼: ${cycleNumber}`,
    `Base: ${BASE}`,
    `Ses: ${BEEP_ENABLED ? 'AÃƒâ€¡IK' : 'KAPALI'}`,
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
  return body.includes("login") || body.includes("giriÃ…Å¸");
}

async function openAddSmart_v2(page, url){
  // 1) Direkt /add/
  await page.goto(url, { waitUntil: "load" });
  
  /* ensure logged in (fallback) */
if (/\/admin\/login\//.test(page.url())) {
  const uVal = process.env.ADMIN_USER ?? "admin";
  const pVal = process.env.ADMIN_PASS ?? "admin";

  // id/name/placeholder/label çoklu strateji
  let u = page.locator('#id_username, input[name="username"], input[name="email"], input#id_user, input[name="user"]').first();
  const uByPh = page.getByPlaceholder(/kullanıcı adı|kullanici adi|email|e-?posta|username/i).first();
  const uByLb = page.getByLabel(/kullanıcı adı|kullanici adi|username|email|e-?posta/i).first();
  if (!(await u.isVisible().catch(()=>false))) u = (await uByPh.isVisible().catch(()=>false)) ? uByPh : uByLb;

  let p = page.locator('#id_password, input[name="password"], input[type="password"]').first();
  const pByPh = page.getByPlaceholder(/parola|şifre|sifre|password/i).first();
  const pByLb = page.getByLabel(/parola|şifre|sifre|password/i).first();
  if (!(await p.isVisible().catch(()=>false))) p = (await pByPh.isVisible().catch(()=>false)) ? pByPh : pByLb;

  try { await u.fill(uVal, { timeout: 10000 }); } catch {}
  try { await p.fill(pVal, { timeout: 10000 }); } catch {}

  const btn = page.getByRole('button', { name: /log in|giriş|oturum|sign in|submit|login/i }).first();
  if (await btn.isVisible().catch(()=>false)) { await btn.click(); }
  else {
    const submit = page.locator('input[type="submit"], button[type="submit"]').first();
    if (await submit.isVisible().catch(()=>false)) { await submit.click(); }
    else { await p.press('Enter').catch(()=>{}); }
  }
  await page.waitForLoadState('domcontentloaded').catch(()=>{});
}
/* end ensure logged in (fallback) */
}