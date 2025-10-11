import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-HEADINGS — has exactly one H1 & sane hierarchy", async ({ page, baseURL }) => {
  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  await page.goto(url, { waitUntil: "domcontentloaded" });

  const h1Count = await page.locator("h1").count();
  expect(h1Count).toBeGreaterThan(0);
  expect(h1Count).toBeLessThan(2); // en fazla 1

  // H1 > H2 > H3 sıralaması: ilk görünen heading seviyeleri artan gitmeli
  const levels = await page.$$eval("h1, h2, h3, h4", els =>
    els.map(e => Number(e.tagName.substring(1)))
  );
  if (levels.length > 1) {
    // bir seviyeden daha küçük bir seviyeye (örn 3 -> 2) sert düşüş olmasın
    for (let i = 1; i < levels.length; i++) {
      if (levels[i] < levels[i-1] && !(levels[i-1] === 2 && levels[i] === 1)) {
        throw new Error(`Heading order odd: ... H${levels[i-1]} -> H${levels[i]}`);
      }
    }
  }
});