// tests/tasks.spec.js
// Enhanced with better error handling

const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");
let PNG, pixelmatch;

const BASE = process.env.BASE_URL || "http://127.0.0.1:8010";

test.use({ storageState: "storage/user.json" });

// ---- Helpers ----
function beep() {
  try {
    process.stdout.write("\x07");
  } catch (err) {
    // Silent fail OK
  }
}

function loadTasks() {
  const rootJson = path.resolve("tasks.json");
  const buildJson = path.resolve("build", "tasks.json");
  
  if (fs.existsSync(rootJson)) {
    console.log(`📄 Loading tasks from: ${rootJson}`);
    return JSON.parse(fs.readFileSync(rootJson, "utf8"));
  }
  if (fs.existsSync(buildJson)) {
    console.log(`📄 Loading tasks from: ${buildJson}`);
    return JSON.parse(fs.readFileSync(buildJson, "utf8"));
  }
  
  throw new Error("❌ tasks.json not found. Run: npx node scripts/build-tasks.js");
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
    steps.push({ 
      cmd: m[1].toLowerCase(), 
      val: m[2].trim().replace(/^"|"$/g, "") 
    });
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
  for (const w of E) {
    if (A.has(w)) hit++;
  }
  return (hit / E.length) >= 0.90;
}

async function ensurePixelLibs() {
  if (!PNG || !pixelmatch) {
    PNG = require("pngjs").PNG;
    pixelmatch = require("pixelmatch");
  }
}

async function visualCompare(page, designRefPath, threshold = 0.85, id = "task") {
  await ensurePixelLibs();
  const refPath = path.resolve(designRefPath);
  
  if (!fs.existsSync(refPath)) {
    throw new Error(`❌ design_ref not found: ${refPath}`);
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
  
  expect(similarity).toBeGreaterThanOrEqual(threshold);
}

// ---- Test Generation ----
const tasks = loadTasks();

if (!Array.isArray(tasks) || tasks.length === 0) {
  throw new Error("❌ tasks.json is empty. Run CSV → JSON compile (scripts/build-tasks.js)");
}

console.log(`\n✓ Loaded ${tasks.length} tasks\n`);

for (const t of tasks) {
  test(`${t.id} — ${t.title}`, async ({ page }) => {
    beep();
    
    const steps = parseSteps(t.job_definition);
    
    // 1) Open
    const open = steps.find(s => s.cmd === "open");
    if (open) {
      const url = open.val.startsWith("http") ? open.val : BASE + open.val;
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 10000 });
    }
    
    // 2) Expect
    for (const s of steps.filter(s => s.cmd === "expect")) {
      await expect(page.locator(s.val)).toBeVisible({ timeout: 5000 });
    }
    
    // 3) Text
    const txt = steps.find(s => s.cmd === "text");
    if (txt) {
      const body = await page.locator("body").innerText();
      const ok = coverage90(body, txt.val);
      expect(ok, "Text coverage <90% (digits ignored)").toBeTruthy();
    }
    
    // 4) Design ref
    if (t.design_ref) {
      const thr = t.visual_threshold ?? 0.85;
      await visualCompare(page, t.design_ref, thr, t.id);
    }
  });
}