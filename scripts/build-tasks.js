const fs = require("fs");
const path = require("path");

function readCSV(p) {
  const txt = fs.readFileSync(p, "utf8").trim();
  if (!txt) return [];
  const [headerLine, ...lines] = txt.split(/\r?\n/);
  const headers = headerLine.split(",").map(s => s.trim());
  return lines
    .map(l => l.trim())
    .filter(Boolean)
    .map(line => {
      const cells = line.split(",").map(s => s.trim());
      const o = {};
      headers.forEach((h, i) => (o[h] = cells[i] ?? ""));
      // tip güvenliği/varsayılanlar
      if (!o.id) o.id = "TASK-" + Math.random().toString(36).slice(2, 7).toUpperCase();
      if (!o.type) o.type = "check";
      if (!o.title) o.title = "Untitled";
      if (!o.job_definition) o.job_definition = "open:/;expect:body";
      if (!o.visual_threshold) o.visual_threshold = 0.9;
      return o;
    });
}

function writeJson(outPath, arr) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(arr, null, 2), "utf8");
  console.log("✓ wrote", outPath, "count:", arr.length);
}

function main() {
  const root = process.cwd();
  const csvPath = path.join(root, "tasks.csv");

  let tasks = [];
  if (fs.existsSync(csvPath)) {
    tasks = readCSV(csvPath);
  }

  // fallback: CSV yoksa en az 1 görev üret
  if (!Array.isArray(tasks) || tasks.length === 0) {
    tasks = [
      {
        id: "SMOKE-001",
        type: "check",
        title: "Admin açılıyor",
        description: "Django admin sayfası yüklenir",
        job_definition: "open:/admin/;expect:Django administration",
        design_ref: "N/A",
        visual_threshold: 0.9
      }
    ];
  }

  // Çoklu hedeflere yaz: spec hangi yolu okursa dolu bulsun
  writeJson(path.join(root, "tasks.json"), tasks);
  writeJson(path.join(root, "tests", "tasks.json"), tasks);
  writeJson(path.join(root, "build", "tasks.json"), tasks);
}
main();