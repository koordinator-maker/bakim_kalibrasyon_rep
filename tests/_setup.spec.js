// Rev: 2025-10-02 14:20 r2
// tests/_setup.spec.js
const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

test("login state üret ve storage/user.json kaydet", async ({ page, context }) => {
  const baseURL = process.env.BASE_URL || "http://127.0.0.1:8010";
  const STORAGE_PATH = path.join(__dirname, "..", "storage", "user.json");
  fs.mkdirSync(path.dirname(STORAGE_PATH), { recursive: true });

  await page.goto(baseURL + "/admin/login/", { waitUntil: "domcontentloaded" });

  await page.fill("#id_username", process.env.ADMIN_USER || "hp");
  await page.fill("#id_password", process.env.ADMIN_PASS || "admin");

  // Farklı submit varyasyonlarını sırayla dene
  const tried = [];
  const submitCandidates = [
    'button[type="submit"]',
    'input[type="submit"]',
    'text=/Log in|Giriş|Oturum Aç/i',
  ];
  let clicked = false;
  for (const sel of submitCandidates) {
    try {
      tried.push(sel);
      if (await page.locator(sel).first().isVisible({ timeout: 1000 })) {
        await Promise.all([
          page.waitForLoadState("networkidle"),
          page.locator(sel).first().click(),
        ]);
        clicked = true;
        break;
      }
    } catch {}
  }
  if (!clicked) {
    throw new Error("Login submit butonu bulunamadı. Denenenler: " + tried.join(", "));
  }

  // Başarıyı admin gösterge öğesi ile doğrula
  const adminUserTools = page.locator("#user-tools");
  try {
    await expect(adminUserTools).toBeVisible({ timeout: 5000 });
  } catch (e) {
    // Tanı: login sayfasında hata mesajı var mı?
    const loginError = page.locator(".errornote, .errorlist, .alert, [role='alert']");
    const currentUrl = page.url();
    // Hata teşhisi için artefakt bırak
    const artifacts = path.join(__dirname, "..", "test-artifacts");
    fs.mkdirSync(artifacts, { recursive: true });
    await page.screenshot({ path: path.join(artifacts, "login-failed.png"), fullPage: true });
    const html = await page.content();
    fs.writeFileSync(path.join(artifacts, "login-page.html"), html, "utf8");

    const hasError = await loginError.first().isVisible().catch(() => false);
    let hint = `Login başarısız görünüyor. URL: ${currentUrl}`;
    if (hasError) hint += " — Login sayfasında hata/uyarı mesajı tespit edildi.";
    hint += `\nKullanıcı: ${process.env.ADMIN_USER || "hp"} — BASE_URL: ${baseURL}`;
    hint += `\nArtefaktlar: test-artifacts/login-failed.png, test-artifacts/login-page.html`;

    throw new Error(hint);
  }

  // Oturum durumunu kaydet
  await context.storageState({ path: STORAGE_PATH });
});
