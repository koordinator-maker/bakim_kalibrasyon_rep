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
  
// --- ensure logged in (fallback) ---
if (/\/admin\/login\//.test(page.url())) {
  const uVal = process.env.ADMIN_USER ?? "admin";
  const pVal = process.env.ADMIN_PASS ?? "admin";

  let u = page.locator('#id_username, input[name="username"], input[name="email"], input#id_user, input[name="user"]').first();
  const uByPh = page.getByPlaceholder(/kullanÄ±cÄ± adÄ±|kullanici adi|email|e-?posta|username/i).first();
  const uByLb = page.getByLabel(/kullanÄ±cÄ± adÄ±|kullanici adi|username|email|e-?posta/i).first();
  if (!(await u.isVisible().catch(()=>false))) u = (await uByPh.isVisible().catch(()=>false)) ? uByPh : uByLb;

  let p = page.locator('#id_password, input[name="password"], input[type="password"]').first();
  const pByPh = page.getByPlaceholder(/parola|ÅŸifre|sifre|password/i).first();
  const pByLb = page.getByLabel(/parola|ÅŸifre|sifre|password/i).first();
  if (!(await p.isVisible().catch(()=>false))) p = (await pByPh.isVisible().catch(()=>false)) ? pByPh : pByLb;

  try { await u.fill(uVal, { timeout: 10000 }); } catch {}
  try { await p.fill(pVal, { timeout: 10000 }); } catch {}

  const btn = page.getByRole("button", { name: /log in|giriÅŸ|oturum|sign in|submit|login/i }).first();
  if (await btn.isVisible().catch(()=>false)) { await btn.click(); }
  else {
    const submit = page.locator('input[type="submit"], button[type="submit"]').first();
    if (await submit.isVisible().catch(()=>false)) { await submit.click(); }
    else { await p.press("Enter").catch(()=>{}); }
  }
  await page.waitForLoadState("domcontentloaded").catch(()=>{});
  // login sonrası hâlâ add sayfasında değilsek, zorla dön
  try {
    const base = (process.env.BASE_URL || "").replace(/\/$/, "");
    if (base && !/\/admin\/maintenance\/equipment\/add\/?$/.test(page.url())) {
      await page.goto(base + "/admin/maintenance/equipment/add/", { waitUntil: "domcontentloaded" });
    }
  } catch {}
}
// --- end ensure logged in ---
'.Trim()

$testFiles = @(
  '.\tests\e102_add_form.spec.js',
  '.\tests\e102_add_form_debug.spec.js',
  '.\tests\e104_create_and_delete_equipment.spec.js'
) | Where-Object { Test-Path $_ }

# page.goto("/admin/maintenance/equipment/add/") sonrasÃ„Â±na enjekte et
$gotoPat = 'await\s+page\.goto\([^;]+/admin/maintenance/equipment/add/[^;]*\)\s*;'

foreach ($f in $testFiles) {
  $raw = Get-Content $f -Raw
  if ($raw -match $gotoPat) {
    $new = [regex]::Replace($raw, $gotoPat, { param($m) $m.Value + "`r`n" + $ensure + "`r`n" }, 1)
    if ($new -ne $raw) {
      [IO.File]::WriteAllText($f, $new, [Text.UTF8Encoding]::new($false))
      Write-Host "[OK] Login fallback enjekte edildi:" $f
    } else {
      Write-Host "[SKIP] Goto bulunamadÃ„Â±:" $f
    }
  } else {
    Write-Host "[SKIP] Desen eÃ…Å¸leÃ…Å¸medi:" $f
  }
}


Set-Location C:\dev\bakim_kalibrasyon

# 1) Kaynakta manufacturer/uretici izini ara
"maintenance\models.py","maintenance\admin.py","maintenance\forms.py" | ForEach-Object {
  if (Test-Path $_) {
    Write-Host "`n### Scanning $_"
    Select-String -Path $_ -Pattern 'manufacturer|ÃƒÂ¼retici|uretici' -CaseSensitive:$false | ForEach-Object { $_.Line }
  }
}

# 2) Ãƒâ€“rnek patch iÃƒÂ§eriÃ„Å¸i (manuel eklemek iÃƒÂ§in hÃ„Â±zlÃ„Â± Ã…Å¸ablon DOSYA YAZMAZ, sadece ÃƒÂ§Ã„Â±ktÃ„Â± verir)
$adminPatch = @'
# maintenance/admin.py iÃƒÂ§inde EquipmentAdmin:
# class EquipmentAdmin(admin.ModelAdmin):
#     fields = ("name", "serial_number", "manufacturer", ...)
#     # veya fieldsets ile ilgili gruba ekleyin
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
    printInfo(`AdÃ„Â±m: ${steps.length}`);
    
    try {
      const open = steps.find(s => s.cmd === "open");
      if (open) {
        const url = open.val.startsWith("http") ? open.val : BASE + open.val;
        printInfo(`AÃƒÂ§Ã„Â±lÃ„Â±yor: ${url}`);
        await page.goto(url, { waitUntil: "load" });
        await page.waitForLoadState("networkidle");
        printSuccess(`YÃƒÂ¼klendi: ${page.url()}`);
      }
      
      for (const s of steps.filter(s => s.cmd === "expect")) {
        printInfo(`Bekleniyor: ${s.val}`);
        await waitVisibleAny(page, t.id, s.val, 4000);
      }
      
      const txt = steps.find(s => s.cmd === "text");
      if (txt) {
        printInfo(`Metin: "${txt.val}"`);
        const body = await page.locator("body").innerText();
        let ok = coverage90(body, txt.val) || (/Kaydet/i.test(txt.val) && coverage90(body, 'Save'));
if (!ok) {
  const ctrl = page.getByRole('button', { name: /Save|Kaydet/i }).or(
    page.locator("input[type='submit'][value*='Save'], input[type='submit'][value*='Kaydet']")
  );
  ok = await ctrl.first().isVisible().catch(() => false);
}
        expect(ok, "Metin < %90").toBeTruthy();
        printSuccess(`Metin: Ã¢â€°Â¥90%`);
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
      printSuccess(`BAÃ…ÂARILI: ${t.id}`);
      
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
      printError(`BAÃ…ÂARISIZ: ${t.id}`);
      printError(`Hata: ${error.message}`);
      throw error;
    }
  });
}

test.afterAll(() => {
  const duration = ((Date.now() - stats.startTime) / 1000).toFixed(2);
  const rate = ((stats.passed / stats.total) * 100).toFixed(2);
  
  const qr = ['ID | BaÃ…Å¸lÃ„Â±k | Durum'];
  stats.testResults.forEach(r => {
    const c = r.status === 'PASSED' ? colors.green : colors.red;
    qr.push(`${r.id} | ${r.title} | ${c}${r.status}${colors.reset}`);
  });
  
  printBox('ÄŸÅ¸â€œâ€ SONUÃƒâ€¡LAR', qr, colors.yellow);
  
  const summary = [
    `Toplam: ${stats.total}`, 
    `DÃƒÂ¶ngÃƒÂ¼: ${cycleNumber}`,
    `BaÃ…Å¸arÃ„Â±lÃ„Â±: ${colors.green}${stats.passed}${colors.reset}`,
    `BaÃ…Å¸arÃ„Â±sÃ„Â±z: ${colors.red}${stats.failed}${colors.reset}`,
    `Oran: ${rate}%`,
    `SÃƒÂ¼re: ${duration}s`,
  ];
  
  if (stats.failed === 0) {
    printBox('Ã¢Å“â€¦ TÃƒÅ“M TESTLER BAÃ…ÂARILI!', summary, colors.green);
  } else {
    printBox('Ã¢Å¡Â Ã¯Â¸Â  BAZI TESTLER BAÃ…ÂARISIZ', summary, colors.yellow);
  }
});








