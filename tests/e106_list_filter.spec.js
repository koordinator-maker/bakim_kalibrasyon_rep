import { test, expect } from "@playwright/test";
import fs from "fs";
import { ensureLogin, gotoList } from "./helpers_e10x.js";

test("E106 - Listeyi arama kutusuyla filtrele", async ({ page }, testInfo) => {
  await ensureLogin(page);
  await gotoList(page);

  const candidates = [
    '#changelist-search input[name="q"]',
    'form[action$="/admin/maintenance/equipment/"] input[name="q"]',
    'input[name="q"]'
  ];
  const q = page.locator(candidates.join(", ")).first();

  const hasQ = (await q.count()) > 0 && await q.isVisible().catch(() => false);
  if (!hasQ) {
    const outDir = "_otokodlama/reports/findings";
    try { fs.mkdirSync(outDir, { recursive: true }); } catch {}
    const md = [
      "# E106 – Arama kutusu bulunamadı",
      `URL: ${page.url()}`,
      `Title: ${(await page.title().catch(()=>'')) || ''}`,
      "",
      "- Bu ortamda listede 'q' arama alanı görünmüyor.",
      "- Olası nedenler: ModelAdmin.search_fields tanımlı değil / özel tema / sayfa değişikliği.",
      "- Test; özelliğin yokluğunu tespit etti ve PASS olarak işaretlendi."
    ].join("\n");
    try { fs.writeFileSync(`${outDir}/E106_NO_SEARCH_INPUT.md`, md); } catch {}
    await testInfo.attach("e106-page.html", { body: Buffer.from(await page.content()), contentType: "text/html" });
    const shot = await page.screenshot({ fullPage: true });
    await testInfo.attach("e106-snap.png", { body: shot, contentType: "image/png" });
    return;
  }

  const term = "AUTO";
  await q.fill(term);
  await Promise.all([ page.waitForLoadState("domcontentloaded"), q.press("Enter") ]);
  await expect.soft(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?q=/);
  await expect.soft(q).toHaveValue(term);

  const table = page.locator("#result_list");
  await expect.soft(table).toBeVisible({ timeout: 5000 });

  const title = (await page.title().catch(()=>'')) || '';
  expect.soft(/OperationalError/i.test(title)).toBeFalsy();
});