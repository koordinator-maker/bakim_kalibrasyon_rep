// scripts/build-tasks.js (CSV'den JSON'a dönüştürücü)
const fs = require('fs');
const path = require('path');
const csv = fs.readFileSync(path.join(process.cwd(), 'tasks_template.csv'), 'utf8');

const lines = csv.trim().split('\r\n');
const headers = lines[0].split(',');
const tasks = [];

for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(',');
    if (values.length === headers.length) {
        let task = {};
        for (let j = 0; j < headers.length; j++) {
            task[headers[j].trim()] = values[j].trim().replace(/^"|"$/g, '');
        }
        tasks.push(task);
    }
}

if (!fs.existsSync('build')) { fs.mkdirSync('build'); }
fs.writeFileSync('build/tasks.json', JSON.stringify(tasks, null, 2));
console.log(`[BUILD] ${tasks.length} görev tasks.json dosyasına başarıyla dönüştürüldü.`);
