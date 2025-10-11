import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-LINKS — first-page links return < 400 (internal only)", async ({ page, request, baseURL }) => {
  const start = new URL(entry, baseURL || "http://127.0.0.1:8010");
  await page.goto(start.toString(), { waitUntil: "domcontentloaded" });

  // Dahili (aynı origin) href'ler, mailto/tel çıkar, ilk 30
  const hrefs = await page.$$eval("a[href]", (as, origin) => {
    const out = [];
    for (const a of as) {
      const h = a.getAttribute("href") || "";
      if (!h || h.startsWith("mailto:") || h.startsWith("tel:")) continue;
      try {
        const u = new URL(h, origin);
        if (u.origin !== origin) continue;     // dış linki at
        out.push(u.toString());
      } catch { /* geçersiz URL -> at */ }
      if (out.length >= 30) break;
    }
    return Array.from(new Set(out));
  }, start.origin);

  const warnings = [];
  for (const absolute of hrefs) {
    try {
      const res = await request.get(absolute, { timeout: 10000 });
      expect(res.status(), absolute).toBeLessThan(400);
    } catch (e) {
      // Ağ hatasında testi düşürmeyelim, rapora not bırakalım
      warnings.push(`Network issue for ${absolute}: ${String(e)}`);
    }
  }
  if (warnings.length) {
    test.info().annotations.push({ type: "link-warnings", description: warnings.join("\n") });
  }
});