import { test, expect } from "@playwright/test";
import { loginIfNeeded, createEquipment, deleteEquipmentByName } from "./_helpers.equip";

test.setTimeout(30000);

test("E105 - Liste arama (sade ve sağlam)", async ({ page }) => {
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const USER = process.env.ADMIN_USER || "admin";
  const PASS = process.env.ADMIN_PASS || "admin123!";

  await loginIfNeeded(page, BASE, USER, PASS);

  // benzersiz isim
  const name = "AUTO-E105-" + Date.now();

  // 1) kayıt oluştur
  await createEquipment(page, name, BASE);

  // 2) arama: doğrudan ?q= ile filtreli listeye git
  const q = encodeURIComponent(name);
  await page.goto(`${BASE}/admin/maintenance/equipment/?q=${q}`, { waitUntil: "domcontentloaded" });

  // 3) sonuç tablosu gelsin
  const table = page.locator("#result_list");
  await expect(table).toBeVisible({ timeout: 10000 });

  // 4) link aramak yerine metni ara (hangi kolonda olursa olsun)
  const cellMatch = table.getByText(name, { exact: true }).first();
  await expect(cellMatch, "Arama sonuçlarında beklenen kayıt görünmedi").toBeVisible({ timeout: 10000 });

  // 5) temizlik
  await deleteEquipmentByName(page, name, BASE);
});