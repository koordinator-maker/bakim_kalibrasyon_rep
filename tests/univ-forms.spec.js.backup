import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-FORMS — first form submits without console/server errors", async ({ page, baseURL }) => {
  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  const errors = [];
  page.on("console", m => { if (m.type() === "error") errors.push(m.text()); });

  await page.goto(url, { waitUntil: "domcontentloaded" });

  const form = page.locator("form").first();
  if (await form.count() === 0) {
    test.info().annotations.push({ type: "note", description: "No <form> on entry page — skipped logically." });
    return;
  }

  // Required input/textarea
  const reqFields = form.locator('input[required], textarea[required]');
  const n = await reqFields.count();
  for (let i = 0; i < n; i++) {
    const el = reqFields.nth(i);
    const type = (await el.getAttribute("type")) || "text";
    const fillVal =
      type === "email" ? "user@example.com" :
      type === "url"   ? "https://example.com" :
      type === "tel"   ? "5555555" :
      type === "number"? "1" :
      type === "password" ? "P@ssw0rd!" :
      "AUTO";
    // checkbox/radio farklı
    if (["checkbox","radio"].includes(type)) { await el.check().catch(()=>{}); }
    else { await el.fill(fillVal).catch(()=>{}); }
  }

  // Required select: ilk uygunu seç
  const selects = form.locator("select");
  const sCount = await selects.count();
  for (let i = 0; i < sCount; i++) {
    const sel = selects.nth(i);
    // boş olmayan ilk option
    await sel.selectOption({ index: 1 }).catch(()=>{});
  }

  // Submit
  const submit = form.locator('button[type="submit"], input[type="submit"]').first();
  if (await submit.count()) {
    await submit.click({ timeout: 5000 }).catch(()=>{});
  } else {
    // buton yoksa Enter
    await form.press("Enter").catch(()=>{});
  }

  // Yükleme bitsin
  await page.waitForLoadState("domcontentloaded");
  // Ağdan son gelen response'u yakala (500 yok)
  const resp = page.response() || null;
  if (resp) {
    const st = resp.status();
    expect(st, "HTTP 5xx after submit").toBeLessThan(500);
  }

  // Tipik sunucu hata ipuçları içerikte olmasın
  const bodyText = (await page.locator("body").innerText()).slice(0, 2000);
  expect(bodyText).not.toMatch(/Server Error|Traceback|Exception|ValueError|TypeError/i);

  // Konsol hatası olmasın
  if (errors.length) test.info().annotations.push({ type: "console-errors", description: errors.join("\n") });
  expect(errors.length, errors.join("\n")).toBe(0);
});