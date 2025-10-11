import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-ROUTES — first 5 internal links open without 5xx and console errors", async ({ page, baseURL, request }) => {
  const base = baseURL || "http://127.0.0.1:8010";
  const start = new URL(entry, base).toString();

  const errors = [];
  page.on("console", m => { if (m.type() === "error") errors.push(m.text()); });

  await page.goto(start, { waitUntil: "domcontentloaded" });

  // Dahili href'leri yakala (mailto/tel ve tam dış linkleri çıkar)
  const hrefs = await page.$$eval("a[href]", as => {
    const out = [];
    for (const a of as) {
      const h = a.getAttribute("href") || "";
      if (!h) continue;
      if (h.startsWith("mailto:") || h.startsWith("tel:")) continue;
      if (h.startsWith("http")) continue; // dış link
      out.push(h);
      if (out.length >= 5) break;
    }
    return Array.from(new Set(out));
  });

  for (const h of hrefs) {
    const target = new URL(h, start).toString();

    // Doğrudan HTTP kontrolü (status < 500)
    const res = await request.get(target);
    expect(res.status(), "HTTP status for " + target).toBeLessThan(500);

    // Tarayıcıda aç ve temel kontroller
    await page.goto(target, { waitUntil: "domcontentloaded" });
    await expect(page).toHaveTitle(/.+/);
    expect(await page.locator("h1, [role='heading']").count(), "No heading on " + target).toBeGreaterThan(0);
    expect((errors.join("\n")), "Console errors on " + target).toBe("");

    // Bir sonraki döngüde temiz başlamak için hataları sıfırla
    errors.length = 0;
  }
});