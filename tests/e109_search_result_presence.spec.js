/**
 * E109 — Arama sonrası sayfa başlığında/sonuç bölümünde doğrulama (ek güvence)
 */
import { test, expect } from "@playwright/test";
import { loginIfNeeded, createEquipment, deleteEquipmentByName } from "./_helpers.equip";

test("E109 - Arama sonrası sonuçta kayıt bulunmalı", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  await loginIfNeeded(page, BASE, USER, PASS);
  const name = "AUTO-E109-" + Date.now();
  await createEquipment(page, name, BASE);

  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded" });
  const q = page.locator('#searchbar,[name="q"]').first();
  await q.fill(name.slice(0, 10)); // kısmi
  await Promise.all([ page.waitForLoadState('domcontentloaded'), page.keyboard.press('Enter') ]);

  // Kayıt satırı + tablonun en az 1 satır göstermesi
  await expect(page.locator(`#result_list a:has-text("${name}")`).first()).toBeVisible();
  await expect(page.locator('#result_list tbody tr')).toHaveCountGreaterThan(0);

  await deleteEquipmentByName(page, name, BASE);
});