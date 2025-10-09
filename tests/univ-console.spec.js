import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-CONSOLE — no console errors on load", async ({ page, baseURL }) => {
  const errors = [];
  page.on("console", m => { if (m.type() === "error") errors.push(m.text()); });

  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  await page.goto(url, { waitUntil: "domcontentloaded" });

  // Hata varsa rapora not düşelim ki raporda görünsün
  if (errors.length) {
    test.info().annotations.push({ type: "console-errors", description: errors.join("\n") });
  }
  expect(errors.length, errors.join("\n")).toBe(0);
});