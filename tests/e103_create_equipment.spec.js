/**
 * Rev: 2025-10-06 12:40 r1
 * E103 — Equipment Kaydetme (stabil form algılama + auto-login)
 */
import { test, expect } from '@playwright/test';
import fs from 'fs';

test('E103 - Equipment Kaydetme (dinamik doldurma)', async ({ page }) => {
  const BASE = (process.env.BASE_URL || 'http://127.0.0.1:8010').replace(/\/$/, '');
  const ADMIN_USER = process.env.ADMIN_USER || 'admin';
  const ADMIN_PASS = process.env.ADMIN_PASS || 'admin123!';

  async function loginIfNeeded() {
    await page.goto(`${BASE}/admin/`, { waitUntil: 'domcontentloaded' });
    if (/\/admin\/login\//.test(page.url())) {
      await page.fill('#id_username', ADMIN_USER);
      await page.fill('#id_password', ADMIN_PASS);
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
        page.locator('input[type="submit"],button[type="submit"]').first().click()
      ]);
    }
  }

  await loginIfNeeded();

  // ADD formuna git ve gerçekten 'add' sayfasında olduğunu garanti et
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]').first();
    if (await addLink.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), addLink.click() ]);
    }
  }

  // Formu bulurken alternatifler kullan
  let form = page.locator('form:has(input[name="_save"])').first();
  if (!(await form.count())) {
    form = page.locator('form[action*="/add/"]').first();
  }
  await expect(form, 'ADD formu görünür değil').toBeVisible();

  const ts = Date.now().toString();
  const nameValue = 'AUTO-NAME-' + ts;

  // İsim alanı için stabil seçiciler
  const nameSel = ['input[name="name"]', '#id_name',
                   'input[type="text"][name], input:not([type])[name]'];
  let filled = false;
  for (const sel of nameSel) {
    const f = form.locator(sel).first();
    if (await f.isVisible().catch(()=>false)) {
      await f.fill(nameValue);
      filled = true;
      break;
    }
  }
  if (!filled) {
    const fallback = form.locator('input[type="text"], input:not([type]), textarea').first();
    if (await fallback.isVisible().catch(()=>false)) {
      await fallback.fill(nameValue);
      filled = true;
    }
  }
  expect(filled, 'Name-like alan bulunamadı').toBeTruthy();

  // Kaydet
  const save = form.locator('input[name="_save"]').first();
  if (await save.isVisible().catch(()=>false)) {
    await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);
  } else {
    const submitAlt = form.locator('button[type="submit"], input[type="submit"]').first();
    await Promise.all([ page.waitForLoadState('domcontentloaded'), submitAlt.click() ]);
  }

  // Başarı sonrası en azından changelist bekleyelim
  await expect(page).toHaveURL(new RegExp('/admin/maintenance/equipment/?$'));

  // Artefakt (tanılama için)
  try { fs.writeFileSync('test-results/e103_add_page.html', await page.content()); } catch {}
});