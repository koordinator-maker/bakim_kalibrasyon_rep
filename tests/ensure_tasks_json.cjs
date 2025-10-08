/* Rev: 2025-10-08 r2 */
const fs = require("fs");
const { execSync } = require("child_process");
const path = require("path");

function existsAny(...paths){ return paths.some(p => fs.existsSync(p)); }
function writeFallback(){
  const fallback = {
    meta: { generatedAt: new Date().toISOString(), source: "globalSetup-fallback" },
    jobs: [{ id: "ADMIN_SMOKE", title: "Admin login smoke", steps: [{ action: "goto", url: "/admin/login/" }] }]
  };
  fs.writeFileSync("tasks.json", JSON.stringify(fallback,null,2));
  fs.mkdirSync("build", { recursive: true });
  fs.writeFileSync(path.join("build","tasks.json"), JSON.stringify(fallback,null,2));
  console.log("[ensure_tasks_json] wrote fallback tasks.json");
}

module.exports = async () => {
  const rootJson  = "tasks.json";
  const buildJson = path.join("build","tasks.json");
  if (existsAny(rootJson, buildJson)) { console.log("[ensure_tasks_json] exists"); return; }
  try {
    if (fs.existsSync("scripts/build-tasks.js")) {
      console.log("[ensure_tasks_json] node scripts/build-tasks.js");
      execSync("node scripts/build-tasks.js", { stdio: "inherit" });
    } else {
      writeFallback();
    }
  } catch (e) {
    console.warn("[ensure_tasks_json] builder failed:", e.message);
    writeFallback();
  }
};
console.log('[globalSetup] OK');
