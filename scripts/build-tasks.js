const fs = require("fs");
const path = require("path");
const csv = require("csv-parse/sync");

const raw = fs.readFileSync("tasks_template.csv", "utf8");
const tasks = csv.parse(raw, { columns: true, skip_empty_lines: true });

fs.mkdirSync("build", { recursive: true });
fs.writeFileSync("build/tasks.json", JSON.stringify(tasks, null, 2));

console.log(`[BUILD] ${tasks.length} görev yazıldı.`);