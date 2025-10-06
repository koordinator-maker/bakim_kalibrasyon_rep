const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

(async () => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const headed = process.env.PW_HEADED === "1";
  const outDir = path.resolve("_otokodlama","out");
  const trDir  = path.resolve("test-results");
  fs.mkdirSync(outDir, { recursive: true });
  fs.mkdirSync(trDir,  { recursive: true });

  const browser = await chromium.launch({ headless: !headed });
  const context = await browser.newContext({ storageState: "storage/user.json" });
  const page = await context.newPage();

  // ADD formuna git ve 'add' sayfasında olduğumuzu garanti et
  const target = `${BASE}/admin/maintenance/equipment/add/`;
  await page.goto(target, { waitUntil: "domcontentloaded" });
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState("domcontentloaded");
    }
  }

  // _save butonu olan formu baz al
  const form = page.locator('form:has(input[name="_save"])').first();
  const formVisible = await form.isVisible().catch(() => false);

  async function dumpInputs(sel) {
    const els = form.locator(sel);
    const n = await els.count();
    const arr = [];
    for (let i=0;i<n;i++){
      const el = els.nth(i);
      const name = await el.getAttribute("name");
      const id   = await el.getAttribute("id");
      const type = await el.getAttribute("type");
      const lab  = await el.evaluate(e => (e.labels?.[0]?.textContent || "").trim());
      arr.push({ selector: sel, name, id, type, label: lab });
    }
    return arr;
  }

  const requiredText = await dumpInputs('input[required][type="text"], input[required]:not([type]), textarea[required]');
  const requiredNum  = await dumpInputs('input[required][type="number"]');
  const requiredDate = await dumpInputs('input[required][type="date"]');
  const requiredSel  = await dumpInputs('select[required]');

  const hasSave      = await form.locator('input[name="_save"]').count().catch(() => 0);
  const hasContinue  = await form.locator('input[name="_continue"], button[name="_continue"]').count().catch(() => 0);
  const altButtons   = await form.locator('button[type="submit"], input[type="submit"]').count().catch(() => 0);

  // HTML + PNG
  const html = await page.content();
  fs.writeFileSync(path.join(trDir, "e104_add_page.html"), html, "utf8");
  await page.screenshot({ path: path.join(trDir, "e104_add_page.png"), fullPage: true });

  // İsim alanı için aday seçiciler
  function nameLikeCandidates(list) {
    const cand = [];
    for (const it of list) {
      const lname = (it.name || "").toLowerCase();
      const lid   = (it.id || "").toLowerCase();
      const llbl  = (it.label || "").toLowerCase();
      if (lname.includes("name") || lid.includes("name") || llbl.includes("isim") || llbl.includes("name")) {
        if (it.name) cand.push(`input[name="${it.name}"]`);
        if (it.id)   cand.push(`#${it.id}`);
      }
    }
    return Array.from(new Set(cand));
  }

  const report = {
    url_after_nav: page.url(),
    form_visible: formVisible,
    counts: {
      text_like: requiredText.length,
      number:    requiredNum.length,
      date:      requiredDate.length,
      select:    requiredSel.length
    },
    buttons: {
      save: hasSave,
      continue: hasContinue,
      submit_variants: altButtons
    },
    recommended_selectors: {
      name_field_pref: nameLikeCandidates(requiredText).slice(0,3),
      save_button: hasSave ? 'input[name="_save"]' : 'button[type="submit"], input[type="submit"]',
      delete_confirm_form: ['#content form:has(input[name="post"])','form[action$="/delete/"]','form button[type="submit"], form input[type="submit"]']
    },
    artifacts: {
      html: path.join("test-results","e104_add_page.html"),
      screenshot: path.join("test-results","e104_add_page.png")
    },
    ts: Date.now()
  };

  fs.writeFileSync(path.join(outDir, "e104_dom_probe.json"), JSON.stringify(report, null, 2), "utf8");
  await browser.close();
  console.log("[probe] wrote _otokodlama/out/e104_dom_probe.json");
})();