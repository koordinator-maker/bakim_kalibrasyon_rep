const fs = require("fs");
const path = require("path");
const csv = require("csv-parse/sync");

const csvPath = path.resolve("tasks_template.csv");
const outPath = path.resolve("build", "tasks.json");

if (!fs.existsSync(csvPath)) {
  console.error("[ERROR] tasks_template.csv bulunamadı!");
  process.exit(1);
}

let csvContent = fs.readFileSync(csvPath, "utf8");
// BOM temizle
if (csvContent.charCodeAt(0) === 0xFEFF) {
  csvContent = csvContent.slice(1);
}

const records = csv.parse(csvContent, {
  columns: true,
  skip_empty_lines: true,
  trim: true,
});

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(records, null, 2), "utf8");

console.log(`[BUILD] ${records.length} görev yazıldı.`);