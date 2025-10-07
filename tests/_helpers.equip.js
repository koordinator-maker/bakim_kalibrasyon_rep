/**
 * Ortak yardımcılar (login, create, delete)
 */
import { expect } from '@playwright/test';

export async function loginIfNeeded(page, BASE, USER, PASS) {
  await page.goto(`${BASE}/admin/`, { waitUntil: 'domcontentloaded' });
  if (/\/admin\/login\//.test(page.url())) {
    await page.fill('#id_username', USER);
    await page.fill('#id_password', PASS);
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
      page.locator('input[type="submit"],button[type="submit"]').first().click(),
    ]);
  }
}

export async function createEquipment(page, nameValue, BASE) {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form).toBeVisible();
  const nameSel = ['input[name="name"]', '#id_name', 'input[type="text"][name], input:not([type])[name]'];
  let filled = false;
  for (const s of nameSel) {
    const f = form.locator(s).first();
    if (await f.isVisible().catch(()=>false)) { await f.fill(nameValue); filled = true; break; }
  }
  if (!filled) { await form.locator('input[type="text"], input:not([type]), textarea').first().fill(nameValue); }
  const save = form.locator('input[name="_save"],button[type="submit"],input[type="submit"]').first();
  await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);
}

export async function deleteEquipmentByName(page, nameValue, BASE) {
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: 'domcontentloaded' });
  const link = page.locator(`#result_list a:has-text("${nameValue}")`).first();
  if (await link.isVisible().catch(()=>false)) {
    await Promise.all([ page.waitForLoadState('domcontentloaded'), link.click() ]);
    // delete
    let clicked = false;
    for (const sel of ['.object-tools a.deletelink','.object-tools a[href$="/delete/"]','.submit-row a.deletelink','#content a[href$="/delete/"]','a[href$="/delete/"]']) {
      const a = page.locator(sel).first();
      if (await a.isVisible().catch(()=>false)) {
        await Promise.all([ page.waitForLoadState('domcontentloaded'), a.click() ]); clicked = true; break;
      }
    }
    if (!clicked) {
      const u = new URL(page.url());
      await page.goto(u.origin + u.pathname.replace(/\/change\/?$/, '/') + 'delete/', { waitUntil: 'domcontentloaded' });
    }
    const btn = page.getByRole('button',{ name: /(Yes|Evet|Si|Sí|Ja|Oui|Sì)/i }).first()
                  .or(page.locator('button[type="submit"],input[type="submit"]').first());
    await Promise.all([ page.waitForLoadState('domcontentloaded'), btn.click() ]);
    await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/?$/);
  }
}