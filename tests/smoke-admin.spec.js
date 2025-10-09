import { test, expect } from "@playwright/test";

test("SMOKE-001 — Admin açılıyor", async ({ page }) => {
  const base = process.env.BASE_URL || "http://127.0.0.1:8010";
  await page.goto(base + "/admin/", { waitUntil: "domcontentloaded" });
  await expect(page.getByText("Django administration")).toBeVisible();
});
