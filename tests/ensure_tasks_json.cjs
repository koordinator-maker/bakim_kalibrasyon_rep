/**
 * Global setup: tasks.json'ı güvenle hazırlar.
 * - Varsa ve doluysa KORUR.
 * - build/tasks.json doluysa onu kullanır.
 * - Yoksa fallback 1 görev yazar.
 * - Her zaman UTF-8 (no BOM) ve dizi formatında yazar.
 */
const fs = require("fs");
const path = require("path");

function readJsonIfAny(p) {
  if (!fs.existsSync(p)) return null;
  try {
    let text = fs.readFileSync(p, "utf8");
    // BOM temizle
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
    const data = JSON.parse(text);
    return data;
  } catch (_) {
    return null;
  }
}

function toArray(json) {
  if (Array.isArray(json)) return json;
  if (!json || typeof json !== "object") return [];
  if (Array.isArray(json.jobs)) return json.jobs;
  return [json];
}

module.exports = async () => {
  const root = path.resolve("tasks.json");
  const build = path.resolve("build", "tasks.json");
  const buildDir = path.dirname(build);

  let data = toArray(readJsonIfAny(root));

  // Kök boşsa build'e bak
  if (!Array.isArray(data) || data.length === 0) {
    const fromBuild = toArray(readJsonIfAny(build));
    if (Array.isArray(fromBuild) && fromBuild.length > 0) {
      data = fromBuild;
    }
  }

  // Hâlâ boşsa fallback üret
  if (!Array.isArray(data) || data.length === 0) {
    data = [
      {
        id: "ADMIN_SMOKE",
        title: "Admin login smoke",
        steps: [{ action: "goto", url: "/admin/login/" }],
      },
    ];
  }

  // build klasörü garanti olsun
  fs.mkdirSync(buildDir, { recursive: true });

  // JSON’u BOM’suz yaz
  const text = JSON.stringify(data, null, 2);
  fs.writeFileSync(root, text, { encoding: "utf8" });
  fs.writeFileSync(build, text, { encoding: "utf8" });

  console.log(`[ensure_tasks_json] ready with ${data.length} item(s)`);
};
