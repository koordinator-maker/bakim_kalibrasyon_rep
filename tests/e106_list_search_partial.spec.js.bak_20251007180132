/**
 * E106 — Equipment listesinde arama (partial/contains)
 */
import { test, expect } from "@playwright/test";
import { loginIfNeeded, createEquipment, deleteEquipmentByName } from "./_helpers.equip";

test("E106 - Liste arama (partial match)", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  await loginIfNeeded(page, BASE, USER, PASS);
  const prefix = "AUTO-E106-";
  const name = prefix + Date.now();

  await createEquipment(page, name, BASE);

  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  const searchBox = page.locator('#searchbar,[name="q"]').first();
  await searchBox.fill(prefix);
  await Promise.all([ page.waitForLoadState('domcontentloaded'), page.keyboard.press('Enter') ]);
  await expect(page.locator(`#result_list a:has-text("${name}")`).first()).toBeVisible();

  await deleteEquipmentByName(page, name, BASE);
});