import { test, expect } from "@playwright/test";

test("UNIV-FORMS — first form submits without console/server errors", async ({ page }) => {
  const base = process.env.BASE_URL || "http://127.0.0.1:8010";
  const errors = [];

  // Console hataları yakala
  page.on("pageerror", (err) => {
    errors.push(`PAGE: ${err.message}`);
  });
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      errors.push(`CONSOLE: ${msg.text()}`);
    }
  });

  // 🔧 FIX: Response listener
  let lastResponse = null;
  page.on('response', resp => { 
    lastResponse = resp; 
  });

  // Admin'e git
  await page.goto(base + "/admin/", { waitUntil: "domcontentloaded" });

  // İlk form bul
  const form = page.locator("form").first();
  await expect(form).toBeVisible({ timeout: 8000 });

  // Required input'ları doldur
  const inputs = form.locator('input[required]:not([type="hidden"]):not([type="submit"])');
  const count = await inputs.count();
  for (let i = 0; i < count; i++) {
    const inp = inputs.nth(i);
    const type = (await inp.getAttribute("type")) || "text";
    if (type === "checkbox") {
      await inp.check({ force: true }).catch(() => {});
    } else {
      await inp.fill("test_value").catch(() => {});
    }
  }

  // Submit butonunu bul ve tıkla
  const submit = form.locator('input[type="submit"], button[type="submit"]').first();
  await submit.click();
  await page.waitForLoadState("domcontentloaded");

  // 🔧 FIX: Response check (yeni API)
  if (lastResponse) {
    const st = lastResponse.status();
    expect(st, "HTTP 5xx after submit").toBeLessThan(500);
  }

  // Body text kontrol
  const bodyText = await page.locator("body").innerText().catch(() => '');
  const snippet = bodyText.slice(0, 2000);
  expect(snippet).not.toMatch(/Server Error|Traceback|Exception|ValueError|TypeError/i);

  // Konsol hatası olmasın
  if (errors.length > 0) {
    test.info().annotations.push({ type: "console-errors", description: errors.join("\n") });
  }
  expect(errors.length, "Console errors:\n" + errors.join("\n")).toBe(0);
});