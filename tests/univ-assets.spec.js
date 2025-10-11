import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-ASSETS — images have alt; css/js requests < 400", async ({ page, request, baseURL }) => {
  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  await page.goto(url, { waitUntil: "domcontentloaded" });

  // IMG alt kontrolü (alt yoksa veya sadece whitespace ise hata)
  const noAlt = await page.$$eval("img", imgs =>
    imgs.filter(img => {
      const alt = (img.getAttribute("alt") || "").trim();
      return alt.length === 0;
    }).length
  );
  expect(noAlt, "Images without alt").toBe(0);

  // CSS/JS istekleri (ilk 30 benzersiz)
  const hrefs = await page.$$eval('link[rel="stylesheet"][href], script[src]', els => {
    const urls = new Set();
    for (const el of els) {
      const u = (el.getAttribute("href") || el.getAttribute("src") || "").trim();
      if (u) urls.add(u);
      if (urls.size >= 30) break;
    }
    return Array.from(urls);
  });

  const base = baseURL || url;
  for (const h of hrefs) {
    const absolute = new URL(h, base).toString();
    const res = await request.get(absolute);
    expect(res.status(), absolute).toBeLessThan(400);
  }
});