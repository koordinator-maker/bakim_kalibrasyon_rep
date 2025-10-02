// Rev: 2025-10-02 16:25 r7
// tests/EQP-003.spec.js
const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

test.describe("EQP-003", () => {
  test("Ekipman Ekleme formunda Üretici Firma alanının varlığı", async ({ page, context }) => {
    const artifacts = path.join(__dirname, "..", "test-artifacts");
    fs.mkdirSync(artifacts, { recursive: true });
    const urlsLog = path.join(artifacts, "eqp003-urls.txt");
    const logUrl = async (p) => fs.appendFileSync(urlsLog, (await p.url()) + "\n");

    // 1) Admin ana sayfa -> login düşme kontrolü
    await page.goto("/admin/", { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.url(), { timeout: 5000 }).not.toMatch(/\/admin\/login\/?/);
    await logUrl(page);

    // 2) Changelist'e git (_direct varyasyonu dahil)
    await page.goto("/admin/maintenance/equipment/", { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.url(), { timeout: 7000 })
      .toMatch(/\/admin\/maintenance\/equipment(?:\/_direct)?\/?$/);
    await logUrl(page);

    // 3) Add/Ekle ile açılabilecek sayfayı bul: navigation veya popup olabilir
    const addBtnCandidates = [
      ".object-tools .addlink",
      "a.addlink",
      'a[href$="/add/"]',
      'a[href*="/equipment/add/"]',
      'a[href*="/equipment/_direct/add/"]',
      'a:has-text("Add")',
      'a:has-text("Ekle")'
    ];

    let targetPage = page;
    let opened = false;
    for (const sel of addBtnCandidates) {
      const loc = page.locator(sel).first();
      try {
        if (await loc.isVisible({ timeout: 700 })) {
          const [maybePopup] = await Promise.all([
            page.waitForEvent("popup").catch(() => null),
            // navigation yoksa sorun değil; popup yakalanırsa onu kullanacağız
            Promise.race([
              page.waitForNavigation({ waitUntil: "domcontentloaded" }).catch(() => null),
              page.waitForLoadState("domcontentloaded").catch(() => null),
              (async () => { /* fallback */ })(),
            ]),
            loc.click()
          ]);
          if (maybePopup) {
            targetPage = maybePopup;
            await targetPage.waitForLoadState("domcontentloaded");
          }
          opened = true;
          break;
        }
      } catch {}
    }

    // Buton bulunamadıysa: iki olası add URL'sini sırayla dene
    if (!opened) {
      const addUrls = [
        "/admin/maintenance/equipment/_direct/add/",
        "/admin/maintenance/equipment/add/",
      ];
      for (const u of addUrls) {
        await page.goto(u, { waitUntil: "domcontentloaded" });
        await logUrl(page);
        if (!/\/admin\/login\/?/.test(await page.url())) { opened = true; break; }
      }
    }

    if (!opened) {
      await page.screenshot({ path: path.join(artifacts, "eqp003-no-add-open.png"), fullPage: true });
      fs.writeFileSync(path.join(artifacts, "eqp003-no-add-open.html"), await page.content(), "utf8");
      throw new Error('Add sayfası açılamadı. Artefaktlar: test-artifacts/eqp003-no-add-open.png, test-artifacts/eqp003-no-add-open.html');
    }

    // 4) Arama yardımcıları — sayfa veya iframe/popup içinde alanı bul
    async function findManufacturerInScope(scope) {
      const candidates = [
        "#id_manufacturer",
        "[name='manufacturer']",
        // label tabanlı (getByLabel, Türkçe/İngilizce)
        { label: /Üretici Firma|Manufacturer/i },
        // bazı tema/layout varyantları
        "[data-field-name='manufacturer'] input",
        ".form-row:has(label:has-text('Manufacturer')) input",
        ".form-row:has(label:has-text('Üretici')) input",
        // generic input fallbacks (placeholder vb.)
        "input[placeholder*='Üretici' i]",
        "input[placeholder*='Manufacturer' i]",
      ];

      // getByLabel için ayrı yol
      for (const c of candidates) {
        try {
          let loc;
          if (typeof c === "string") {
            loc = scope.locator(c).first();
          } else if (c.label) {
            loc = scope.getByLabel(c.label).first();
          }
          if (loc && await loc.isVisible({ timeout: 600 }).catch(() => false)) {
            return loc;
          }
        } catch {}
      }
      return null;
    }

    async function searchAllContexts(rootPage) {
      // 4.a) Ana sayfa
      const direct = await findManufacturerInScope(rootPage);
      if (direct) return { owner: "page", loc: direct };

      // 4.b) Iframe'ler
      for (const fr of rootPage.frames()) {
        const fnd = await findManufacturerInScope(fr);
        if (fnd) return { owner: "frame", loc: fnd, frameUrl: fr.url() };
      }

      // 4.c) Popup sayfaları
      for (const p of rootPage.context().pages()) {
        if (p === rootPage) continue;
        const fnd = await findManufacturerInScope(p);
        if (fnd) return { owner: "popup", loc: fnd, pageUrl: await p.url() };
        for (const fr of p.frames()) {
          const fnd2 = await findManufacturerInScope(fr);
          if (fnd2) return { owner: "popup-frame", loc: fnd2, frameUrl: fr.url(), pageUrl: await p.url() };
        }
      }
      return null;
    }

    // Küçük bir bekleme: ağır tema/component yüklemeleri için
    await targetPage.waitForTimeout(300);
    const hit = await searchAllContexts(targetPage);

    if (!hit) {
      await targetPage.screenshot({ path: path.join(artifacts, "eqp003-field-missing.png"), fullPage: true });
      fs.writeFileSync(path.join(artifacts, "eqp003-add-form.html"), await targetPage.content(), "utf8");
      throw new Error("Üretici Firma alanı bulunamadı. Artefaktlar: test-artifacts/eqp003-field-missing.png, test-artifacts/eqp003-add-form.html");
    }

    // Ek doğrulama: alan görünür
    await expect(hit.loc).toBeVisible({ timeout: 2000 });
  });
});
