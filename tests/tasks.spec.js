// tests/tasks.spec.js
// - Her testte beep
// - job_definition: open:/path | expect:#sel | text:"..." | (design_ref varsa pixelmatch)
// - Metin kontrolü: rakamlar yok sayılır; %90 kapsama
const { test, expect } = require("@playwright/test");
const fs   = require("fs");
const path = require("path");
let PNG, pixelmatch;

const BASE = process.env.BASE_URL || "http://127.0.0.1:8010";

// Tüm testlere auth state uygula (setup ta üretildi)
test.use({ storageState: "storage/user.json" });

// ---------- yardımcılar ----------
function beep(){ try{ process.stdout.write("\x07"); }catch{} }

function loadTasks(){
  const rootJson  = path.resolve("tasks.json");
  const buildJson = path.resolve("build","tasks.json");
  if (fs.existsSync(rootJson))  return JSON.parse(fs.readFileSync(rootJson,"utf8"));
  if (fs.existsSync(buildJson)) return JSON.parse(fs.readFileSync(buildJson,"utf8"));
  throw new Error("tasks.json bulunamadı (kök ya da build/). Önce: npx node scripts/build-tasks.js");
}

function parseSteps(jobDef){
  const steps = [];
  for (const raw of String(jobDef||"").split(";")){
    const part = raw.trim(); if (!part) continue;
    const m = part.match(/^(\w+)\s*:\s*(.+)$/);
    if (!m){ steps.push({cmd:"note", val:part}); continue; }
    steps.push({ cmd:m[1].toLowerCase(), val:m[2].trim().replace(/^"|"$/g,"") });
  }
  return steps;
}

function normalizeWords(s){
  return String(s||"")
    .replace(/\d+/g, " ")          // sayıları yok say
    .replace(/[^\p{L}\s]/gu, " ")  // noktalama/simge at
    .toLowerCase()
    .split(/\s+/).filter(Boolean);
}
function coverage90(actualText, expectedText){
  const A = new Set(normalizeWords(actualText));
  const E = normalizeWords(expectedText);
  if (!E.length) return true;
  let hit = 0; for (const w of E) if (A.has(w)) hit++;
  return (hit/E.length) >= 0.90;
}

async function ensurePixelLibs(){
  if (!PNG || !pixelmatch){
    PNG = require("pngjs").PNG;
    pixelmatch = require("pixelmatch");
  }
}

// >>> DÜZELTİLMİŞ: N/A/boş/eksik referans = SKIP (throw yok)
async function visualCompare(page, designRefPath, threshold = 0.85, id = "task"){
  await ensurePixelLibs();

  const rawRef = (designRefPath ?? "").toString().trim();
  if (!rawRef || rawRef.toUpperCase() === "N/A"){
    console.warn(`[VISUAL] ${id}: design_ref empty/N/A → skip`);
    return;
  }
  const refPath = path.resolve(rawRef);
  if (!fs.existsSync(refPath)){
    console.warn(`[VISUAL] ${id}: reference not found at ${refPath} → skip`);
    return;
  }

  const outDir = path.resolve("targets","actual");
  fs.mkdirSync(outDir, { recursive:true });
  const actPath = path.join(outDir, `${id}.png`);
  await page.screenshot({ path: actPath, fullPage:true });

  const ref = PNG.sync.read(fs.readFileSync(refPath));
  const act = PNG.sync.read(fs.readFileSync(actPath));
  const w = Math.min(ref.width, act.width);
  const h = Math.min(ref.height, act.height);
  const refCrop = new PNG({ width:w, height:h });
  const actCrop = new PNG({ width:w, height:h });
  PNG.bitblt(ref, refCrop, 0,0, 0,0, w,h);
  PNG.bitblt(act, actCrop, 0,0, 0,0, w,h);

  const diff  = new PNG({ width:w, height:h });
  const mismatch = pixelmatch(refCrop.data, actCrop.data, diff.data, w, h, { threshold:0.1 });
  const similarity = 1 - mismatch/(w*h);
  expect(similarity).toBeGreaterThanOrEqual(threshold);
}

// ---------- test üretimi ----------
const tasks = loadTasks();
if (!Array.isArray(tasks) || tasks.length === 0){
  throw new Error("tasks.json boş. CSV → JSON derlemesi yapın (scripts/build-tasks.js).");
}

for (const t of tasks){
  test(`${t.id} — ${t.title}`, async ({ page }) => {
    beep(); // döngü başı bip

    const steps = parseSteps(t.job_definition);

    // 1) open
    const open = steps.find(s => s.cmd === "open");
    if (open){
      const url = open.val.startsWith("http") ? open.val : BASE + open.val;
      await page.goto(url, { waitUntil:"domcontentloaded" });
    }

    // 2) expect:<css>
    for (const s of steps.filter(s => s.cmd === "expect")){
      await expect(page.locator(s.val)).toBeVisible({ timeout:3000 });
    }

    // 3) text:"..."
    const txt = steps.find(s => s.cmd === "text");
    if (txt){
      const body = await page.locator("body").innerText();
      const ok = coverage90(body, txt.val);
      expect(ok, "Metin kapsama <%90 (rakamlar yok sayıldı)").toBeTruthy();
    }

    // 4) design_ref
    if (t.design_ref){
      const thr = t.visual_threshold ?? 0.85;
      await visualCompare(page, t.design_ref, thr, t.id);
    }
  });
}
