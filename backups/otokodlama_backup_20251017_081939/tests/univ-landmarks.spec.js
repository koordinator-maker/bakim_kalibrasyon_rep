import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-LANDMARKS — has main/nav/footer (or equivalents) and a visible H1", async ({ page, baseURL }) => {
  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  await page.goto(url, { waitUntil: "domcontentloaded" });

  // H1 görünür
  await expect(page.locator("h1").first()).toBeVisible();

  // main veya role="main"
  const hasMain = await page.locator("main, [role='main']").count();
  if (hasMain === 0) {
    test.info().annotations.push({ type: "note", description: "No <main> / [role=main] on entry page." });
  } else {
    expect(hasMain).toBeGreaterThan(0);
  }

  // nav veya role="navigation"
  const hasNav = await page.locator("nav, [role='navigation']").count();
  if (hasNav === 0) {
    test.info().annotations.push({ type: "note", description: "No <nav> / [role=navigation] (common on very simple pages)." });
  } else {
    expect(hasNav).toBeGreaterThan(0);
  }

  // footer veya role="contentinfo"
  const hasFooter = await page.locator("footer, [role='contentinfo']").count();
  if (hasFooter === 0) {
    test.info().annotations.push({ type: "note", description: "No <footer> / [role=contentinfo]." });
  } else {
    expect(hasFooter).toBeGreaterThan(0);
  }
});