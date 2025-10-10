const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

function loadTasks() {
  const candidates = [
    process.env.TASKS_JSON && path.resolve(process.env.TASKS_JSON),
    path.resolve("tests","tasks.json"),
    path.resolve("tasks.json"),
    path.resolve("build","tasks.json"),
  ].filter(Boolean);
  for (const p of candidates) {
    if (p && fs.existsSync(p)) {
      try {
        const arr = JSON.parse(fs.readFileSync(p, "utf8"));
        if (Array.isArray(arr) && arr.length) return arr;
      } catch {}
    }
  }
  return [];
}

function parseJob(def) {
  const steps = [];
  if (!def) return steps;
  for (const raw of def.split(";").map(s => s.trim()).filter(Boolean)) {
    if (raw.startsWith("open:"))   steps.push({ cmd:"open",   val: raw.slice(5) });
    else if (raw.startsWith("expect:")) steps.push({ cmd:"expect", val: raw.slice(7) });
    else if (raw.startsWith("text:"))   steps.push({ cmd:"text",   val: raw.slice(5) });
  }
  return steps;
}

test.describe("Tasks", () => {
  const tasks = loadTasks();
  test.skip(!tasks.length, "tasks.json boş");

  for (const t of tasks) {
    test(`${t.id} — ${t.title}`, async ({ page }) => {
      const steps = parseJob(t.job_definition || "");

      // 1) open:
      for (const s of steps.filter(x => x.cmd === "open")) {
        await page.goto(s.val);
      }

      // 2) expect:<css> — s.val içindeki wrap tırnakları temizle ve css/text karar ver
for (const s of steps.filter(s => s.cmd === "expect")){
  const val = (s.val || "").replace(/^["']|["']$/g, "").trim();
  const isCss = /[#.\[\(]|^\/\//.test(val);          // css özel karakteri veya // ile başlıyorsa
  const loc   = isCss ? page.locator(val) : page.getByText(val, { exact: false });
  await expect(loc).toBeVisible({ timeout: 5000 });
}

// 3) text:
      for (const s of steps.filter(x => x.cmd === "text")) {
        await expect(page.getByText(s.val, { exact: false })).toBeVisible({ timeout: 5000 });
      }
    });
  }
});

