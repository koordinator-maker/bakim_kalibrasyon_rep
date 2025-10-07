/**
 * E105 — Equipment listesinde arama (exact)
 */
import { test, expect } from "@playwright/test";
import { loginIfNeeded, createEquipment, deleteEquipmentByName } from "./_helpers.equip";

test("E105 - Liste arama (exact match)", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  await loginIfNeeded(page, BASE, USER, PASS);
  const name = "AUTO-E105-" + Date.now();

  await createEquipment(page, name, BASE);

  // Changelist ve arama
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  const searchBox = page.locator('#searchbar,[name="q"]').first();
  await expect(searchBox).toBeVisible();
  await searchBox.fill(name);
  await Promise.all([
    page.waitForLoadState('domcontentloaded'),
    page.keyboard.press('Enter'),
  ]);
  // satır görünsün
  await expect(page.locator(`#result_list a:has-text("${name}")`).first()).toBeVisible();

  await deleteEquipmentByName(page, name, BASE);
});