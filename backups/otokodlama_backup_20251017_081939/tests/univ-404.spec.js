import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

test("UNIV-404 — unknown route returns 4xx and shows a page", async ({ page, baseURL }) => {
  const base = baseURL || "http://127.0.0.1:8010";
  const bad = "/__univ_not_found__/" + Date.now();
  const url = new URL(bad, new URL(entry, base)).toString();

  const resp = await page.goto(url, { waitUntil: "domcontentloaded" });
  expect(resp, "No response for 404 page").toBeTruthy();

  const status = resp ? resp.status() : 0; // <-- düzeltme
  expect(status).toBeGreaterThanOrEqual(400);
  expect(status).toBeLessThan(500); // 404/410 vb. olmalı, 5xx olmamalı

  // Basit görünürlük: H1 ya da ana içerik benzeri bir şey
  expect(await page.locator("h1, [role=\"heading\"]").count()).toBeGreaterThan(0);
  const body = (await page.locator("body").innerText()).slice(0, 2000);
  expect(body).not.toMatch(/Traceback|Server Error|Exception/i);
});