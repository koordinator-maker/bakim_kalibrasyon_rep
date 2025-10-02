// Rev: 2025-10-02 14:55 r3
// tests/_setup.spec.js
const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

test("login state üret ve storage/user.json kaydet", async ({ page, context }) => {
  const baseURL = process.env.BASE_URL || "http://127.0.0.1:8010";
  const STORAGE_PATH = path.join(__dirname, "..", "storage", "user.json");
  fs.mkdirSync(path.dirname(STORAGE_PATH), { recursive: true });

  // 1) Login sayfasına git
  await page.goto(baseURL + "/admin/login/", { waitUntil: "domcontentloaded" });

  // 2) Alanları doldur
  await page.fill("#id_username", process.env.ADMIN_USER || "hp");
  await page.fill("#id_password", process.env.ADMIN_PASS || "admin");

  // 3) Gönder (çeşitli submit varyasyonları)
  const submitCandidates = [
    'button[type="submit"]',
    'input[type="submit"]',
    'text=/Log in|Giriş|Oturum Aç/i',
  ];
  let clicked = false;
  for (const sel of submitCandidates) {
    try {
      const loc = page.locator(sel).first();
      if (await loc.isVisible({ timeout: 1000 })) {
        await Promise.all([
          page.waitForLoadState("networkidle"),
          loc.click()
        ]);
        clicked = true;
        break;
      }
    } catch {}
  }
  if (!clicked) throw new Error("Login submit butonu bulunamadı.");

  // 4) Başarı ölçütleri (tema farklarına dayanıklı):
  // - URL /admin/ (ve login değil)
  // - veya admin tipik metin/öge görünür: "Site administration", "Django administration",
  //   "Kullanıcı araçları", "Çıkış/Log out" linki, ana başlık vb.
  let success = false;
  const deadline = Date.now() + 7000; // max 7sn bekle
  while (Date.now() < deadline) {
    const url = page.url();
    if (/\/admin\/?$/.test(url) && !/\/admin\/login\/?/.test(url)) {
      success = true;
      break;
    }
    const candidates = [
      page.locator('text=/Site administration|Django administration|Site yönetimi|Django Yönetimi/i'),
      page.locator("#user-tools"),
      page.locator('text=/Log out|Çıkış/i'),
      page.locator("main h1"),
    ];
    for (const c of candidates) {
      if (await c.first().isVisible().catch(()=>false)) {
        success = true;
        break;
      }
    }
    if (success) break;
    await page.waitForTimeout(250);
  }

  if (!success) {
    // Tanılama artefaktları
    const artifacts = path.join(__dirname, "..", "test-artifacts");
    fs.mkdirSync(artifacts, { recursive: true });
    await page.screenshot({ path: path.join(artifacts, "login-check-failed.png"), fullPage: true });
    fs.writeFileSync(path.join(artifacts, "login-check-page.html"), await page.content(), "utf8");
    throw new Error(`Login sonrası başarı doğrulanamadı. URL: ${page.url()}\nArtefaktlar: test-artifacts/login-check-failed.png, test-artifacts/login-check-page.html`);
  }

  // 5) Oturum durumunu kaydet
  await context.storageState({ path: STORAGE_PATH });
});
