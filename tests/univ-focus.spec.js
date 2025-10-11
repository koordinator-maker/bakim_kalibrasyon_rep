import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-FOCUS — tab order cycles through focusables without traps", async ({ page, baseURL }) => {
  const start = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  await page.goto(start, { waitUntil: "domcontentloaded" });

  // Odaklanabilir adaylar (görünür olanlar)
  const sel = [
    "a[href]", "button", "input", "select", "textarea",
    "[tabindex]:not([tabindex='-1'])", "[role='button']", "[contenteditable='true']"
  ].join(", ");
  const focusables = page.locator(sel).filter({ hasNot: page.locator("[disabled]") });

  const total = await focusables.count();
  if (total === 0) {
    test.info().annotations.push({ type: "note", description: "No focusable elements on entry page." });
    return;
  }

  // İlk odak: body ise ilk adaya zorla
  await page.keyboard.press("Tab");
  let active = await page.evaluate(() => document.activeElement && (document.activeElement.id || document.activeElement.outerHTML));
  const seen = new Set([active || ""]);

  // En çok 25 adım: tıkanma/loop kontrolü
  for (let i = 0; i < 25; i++) {
    const handle = await page.evaluateHandle(() => document.activeElement);
    const box = await handle.asElement()?.boundingBox();
    // Odaklanan eleman görünür mü?
    expect(box, "Focused element should be visible in viewport").toBeTruthy();

    await page.keyboard.press("Tab");
    active = await page.evaluate(() => document.activeElement && (document.activeElement.id || document.activeElement.outerHTML));

    if (seen.has(active || "")) {
      // Döngüye geri geldik: bu iyi—tuzak yok demek. Testi bitir.
      break;
    }
    seen.add(active || "");
  }

  // Çok az ilerleme = tuzak şüphesi
  expect(seen.size, "Tab focus seems stuck (possible trap)").toBeGreaterThan(1);
});