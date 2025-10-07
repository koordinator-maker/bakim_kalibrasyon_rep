/**
 * E107 — Equipment düzenle (name değiştir)
 */
import { test, expect } from "@playwright/test";
import { loginIfNeeded, createEquipment, deleteEquipmentByName } from "./_helpers.equip";

test("E107 - Düzenle ve kaydet", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  await loginIfNeeded(page, BASE, USER, PASS);
  const name = "AUTO-E107-" + Date.now();
  const newName = name + "-EDIT";

  await createEquipment(page, name, BASE);

  // change sayfasına
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  await Promise.all([
    page.waitForLoadState('domcontentloaded'),
    page.locator(`#result_list a:has-text("${name}")`).first().click()
  ]);

  // name alanını değiştir
  const form = page.locator('form:has(input[name="_save"])').first();
  const nameInput = form.locator('input[name="name"],#id_name,input[type="text"][name]').first();
  await nameInput.fill(newName);
  const save = form.locator('input[name="_save"],button[type="submit"],input[type="submit"]').first();
  await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);

  // listede yeni ad görünsün
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  await expect(page.locator(`#result_list a:has-text("${newName}")`).first()).toBeVisible();

  await deleteEquipmentByName(page, newName, BASE);
});