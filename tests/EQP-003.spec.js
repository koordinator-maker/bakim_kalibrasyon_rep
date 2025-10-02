// Rev: 2025-10-02 17:30 r11
// tests/EQP-003.spec.js
const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

test.describe("EQP-003", () => {
  test("Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page }) => {
    const artifacts = path.join(__dirname, "..", "test-artifacts");
    fs.mkdirSync(artifacts, { recursive: true });

    const LABEL_TEXTS = [/Üretici Firma|Üretici|İmalatçı|Manufacturer|Brand|Marka|Tedarikçi|Supplier|Vendor/i];
    const NAME_CHUNKS  = ["manufact","producer","maker","vendor","supplier","brand","marka","uretic","üretic","imalat","firma"];
    const FIELD_CLASS_CHUNKS = ["field-manufacturer","field-brand","field-producer","field-supplier","field-vendor","field-marka"];

    // 1) Admin -> login düşme kontrolü
    await page.goto("/admin/", { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.url(), { timeout: 5000 }).not.toMatch(/\/admin\/login\/?/);

    // 2) Changelist -> Add (_direct varyasyonu dahil)
    await page.goto("/admin/maintenance/equipment/", { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.url(), { timeout: 7000 }).toMatch(/\/admin\/maintenance\/equipment(?:\/_direct)?\/?$/);

    // Add butonu veya direkt URL
    const addTargets = [
      ".object-tools .addlink","a.addlink",'a[href$="/add/"]',
      'a[href*="/equipment/add/"]','a[href*="/equipment/_direct/add/"]',
      'a:has-text("Add")','a:has-text("Ekle")'
    ];
    let opened = false;
    for (const sel of addTargets) {
      const a = page.locator(sel).first();
      if (await a.isVisible({ timeout: 500 }).catch(()=>false)) {
        await Promise.all([page.waitForLoadState("domcontentloaded").catch(()=>{}), a.click()]);
        opened = true; break;
      }
    }
    if (!opened) {
      for (const u of ["/admin/maintenance/equipment/_direct/add/","/admin/maintenance/equipment/add/"]) {
        await page.goto(u, { waitUntil: "domcontentloaded" });
        if (!/\/admin\/login\/?/.test(page.url())) { opened = true; break; }
      }
    }
    if (!opened) {
      await page.screenshot({ path: path.join(artifacts, "eqp003-no-add-open.png"), fullPage: true });
      fs.writeFileSync(path.join(artifacts, "eqp003-no-add-open.html"), await page.content(), "utf8");
      throw new Error("Add sayfası açılamadı. Artefakt: test-artifacts/eqp003-no-add-open.*");
    }

    // 3) Dinamik yükleme için akıllı bekleme (en çok 15 sn)
    const end = Date.now() + 15000;
    while (Date.now() < end) {
      const hasFormRow = await page.locator(".form-row, .form-group, fieldset, form").first().isVisible().catch(()=>false);
      const hasInputs  = await page.locator("input, select, textarea").first().isVisible().catch(()=>false);
      if (hasFormRow || hasInputs) break;
      await page.waitForTimeout(300);
    }

    // 4) Sayfadaki label–for ve input/select’leri JSON dumpla (teşhis için)
    const dump = await page.evaluate(() => {
      const R = [];
      document.querySelectorAll("label").forEach(l => R.push({kind:"label", text:(l.textContent||"").trim(), forId:l.getAttribute("for")||""}));
      document.querySelectorAll(".form-row, .form-group, .field-row, .row, fieldset").forEach(c => {
        R.push({kind:"container", class:c.className||"", text:(c.textContent||"").trim().replace(/\s+/g," ").slice(0,200)});
      });
      document.querySelectorAll("input, select, textarea").forEach(el => {
        R.push({kind:el.tagName.toLowerCase(), id:el.id||"", name:el.name||"", class:el.className||"", placeholder:el.getAttribute("placeholder")||"", type:el.getAttribute("type")||""});
      });
      return R;
    });
    fs.writeFileSync(path.join(artifacts,"eqp003-page-dump.json"), JSON.stringify(dump,null,2), "utf8");

    // 5) Arama yardımcıları
    async function byLabelFor(scope) {
      const hits = await scope.evaluate((patterns) => {
        const out = [];
        const labs = Array.from(document.querySelectorAll("label"));
        for (const l of labs) {
          const txt = (l.textContent||"").trim();
          if (patterns.some(rx => new RegExp(rx, "i").test(txt))) {
            out.push({ txt, forId: l.getAttribute("for")||"" });
          }
        }
        return out;
      }, LABEL_TEXTS.map(r=>r.source));
      for (const h of hits) {
        if (!h.forId) continue;
        const loc = scope.locator("#"+CSS.escape(h.forId)).first();
        if (await loc.isVisible({ timeout: 700 }).catch(()=>false)) return loc;
      }
      return null;
    }

    async function byFieldContainer(scope) {
      // Django admin klasiği: .form-row.field-<name>
      for (const cls of FIELD_CLASS_CHUNKS) {
        const cont = scope.locator(`.form-row.${cls}, .${cls}`).first();
        if (await cont.isVisible({ timeout: 300 }).catch(()=>false)) {
          const trySel = ["select","input","textarea",".related-widget-wrapper select",".related-widget-wrapper input"];
          for (const s of trySel) {
            const loc = cont.locator(s).first();
            if (await loc.isVisible({ timeout: 300 }).catch(()=>false)) return loc;
          }
        }
      }
      return null;
    }

    async function byAttr(scope) {
      const sels = [];
      for (const chunk of NAME_CHUNKS) {
        sels.push(`[id*='${chunk}' i]`, `[name*='${chunk}' i]`, `select[id*='${chunk}' i]`, `select[name*='${chunk}' i]`);
        sels.push(`input[name$='-${chunk}']`, `select[name$='-${chunk}']`);
      }
      sels.push(
        ".related-widget-wrapper select",".related-widget-wrapper input",
        "input[placeholder*='Üretici' i]", "input[placeholder*='Manufacturer' i]", "input[placeholder*='Brand' i]", "input[placeholder*='Marka' i]"
      );
      for (const s of sels) {
        const loc = scope.locator(s).first();
        if (await loc.isVisible({ timeout: 300 }).catch(()=>false)) return loc;
      }
      return null;
    }

    async function search(root) {
      // Page
      let hit = await byLabelFor(root) || await byFieldContainer(root) || await byAttr(root);
      if (hit) return hit;
      // Frames
      for (const fr of root.frames()) {
        hit = await byLabelFor(fr) || await byFieldContainer(fr) || await byAttr(fr);
        if (hit) return hit;
      }
      // Popups
      for (const p of root.context().pages()) {
        if (p === root) continue;
        hit = await byLabelFor(p) || await byFieldContainer(p) || await byAttr(p);
        if (hit) return hit;
        for (const fr of p.frames()) {
          hit = await byLabelFor(fr) || await byFieldContainer(fr) || await byAttr(fr);
          if (hit) return hit;
        }
      }
      return null;
    }

    const loc = await search(page);

    if (!loc) {
      await page.screenshot({ path: path.join(artifacts, "eqp003-field-missing.png"), fullPage: true });
      fs.writeFileSync(path.join(artifacts, "eqp003-add-form.html"), await page.content(), "utf8");
      throw new Error("Üretici Firma alanı bulunamadı. Artefaktlar: test-artifacts/eqp003-field-missing.png, test-artifacts/eqp003-add-form.html");
    }

    await expect(loc).toBeVisible({ timeout: 4000 });
  });
});
