/* Rev: 2025-10-08 r1 */
const fs = require("fs");
const path = require("path");

function readCsvRows(p) {
  if (!fs.existsSync(p)) return null;
  const raw = fs.readFileSync(p, "utf8").split(/\r?\n/).filter(Boolean);
  const hdr = raw.shift().split(",").map(s=>s.trim());
  return raw.map(line=>{
    const cols = line.split(",").map(s=>s.trim());
    const obj={}; hdr.forEach((h,i)=>obj[h]=cols[i] ?? "");
    return obj;
  });
}

function makeDefaultPlan() {
  return {
    meta: { generatedAt: new Date().toISOString(), source: "default" },
    jobs: [
      {
        id: "ADMIN_SMOKE",
        title: "Admin login smoke",
        steps: [
          { action: "goto",   url: "/admin/login/" },
          { action: "expect", selector: "input[name=username]" },
          { action: "expect", selector: "input[name=password]" }
        ]
      }
    ]
  };
}

function csvToPlan(rows) {
  // Beklenen en basit şema: id,title,action,selector,url
  // Aynı id altındaki satırlar tek job’ın adımları olur.
  const byId = new Map();
  for (const r of rows) {
    const id = r.id || "JOB";
    if (!byId.has(id)) byId.set(id, { id, title: r.title || id, steps: [] });
    byId.get(id).steps.push({
      action: r.action || "goto",
      selector: r.selector || "",
      url: r.url || ""
    });
  }
  return { meta: { generatedAt: new Date().toISOString(), source: "csv" },
           jobs: Array.from(byId.values()) };
}

function ensureDirs() {
  for (const d of ["build"]) {
    if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
  }
}

(function main(){
  ensureDirs();
  const csvPath = path.join("ops","ui_validate.csv"); // varsa bundan türet
  let plan;
  const rows = readCsvRows(csvPath);
  if (rows && rows.length) plan = csvToPlan(rows);
  else {
    // ikinci şans: tasks_template.csv
    const t = readCsvRows("tasks_template.csv");
    plan = (t && t.length) ? csvToPlan(t) : makeDefaultPlan();
  }
  const out = JSON.stringify(plan, null, 2);
  fs.writeFileSync("tasks.json", out);
  fs.writeFileSync(path.join("build","tasks.json"), out);
  console.log("Wrote tasks.json and build/tasks.json");
})();