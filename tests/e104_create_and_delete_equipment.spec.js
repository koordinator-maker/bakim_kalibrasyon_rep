/**
 * E104 — Equipment oluştur & sil (dayanıklı silme akışı)
 */
import { test, expect } from '@playwright/test';
import fs from 'fs';

test('E104 - Equipment oluştur ve sil (temizlik)', async ({ page }) => {
  const BASE = (process.env.BASE_URL || 'http://127.0.0.1:8010').replace(/\/$/, '');
  const USER = process.env.ADMIN_USER || 'admin';
  const PASS = process.env.ADMIN_PASS || 'admin123!';

  async function loginIfNeeded() {
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

  await loginIfNeeded();

  // 1) Add form
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  let form = page.locator('form:has(input[name="_save"])').first();
  if (!(await form.count())) form = page.locator('form[action*="/add/"]').first();
  await expect(form, 'ADD formu görünür değil').toBeVisible();

  // 2) İsim doldur (stabil + fallback)
  const ts = Date.now().toString();
  const nameValue = 'AUTO-NAME-' + ts;
  const nameSel = ['input[name="name"]', '#id_name', 'input[type="text"][name], input:not([type])[name]'];
  let filled = false;
  for (const sel of nameSel) {
    const f = form.locator(sel).first();
    if (await f.isVisible().catch(()=>false)) { await f.fill(nameValue); filled = true; break; }
  }
  if (!filled) {
    const fb = form.locator('input[type="text"], input:not([type]), textarea').first();
    if (await fb.isVisible().catch(()=>false)) { await fb.fill(nameValue); filled = true; }
  }
  expect(filled, 'E104: Name-like alan bulunamadı').toBeTruthy();

  // 3) Kaydet → change
  const save = form.locator('input[name="_save"]').first();
  if (await save.isVisible().catch(()=>false)) {
    await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);
  } else {
    const submitAlt = form.locator('button[type="submit"], input[type="submit"]').first();
    await Promise.all([ page.waitForLoadState('domcontentloaded'), submitAlt.click() ]);
  }

  // Listeye düştüysek ada göre change'e gir
  if (!/\/change\/?$/.test(page.url())) {
    const rowLink = page.locator(`#result_list a:has-text("${nameValue}")`).first();
    if (await rowLink.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), rowLink.click() ]);
    }
  }
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\d+\/change\/|\/change\/?$/);
  const changeForm = page.locator('form:has(input[name="_save"])').first();
  await expect(changeForm, 'CHANGE formu görünür değil').toBeVisible();

  // 4) Delete linki (çoklu strateji + URL fallback)
  const deleteCandidates = [
    '.object-tools a.deletelink',
    '.object-tools a[href$="/delete/"]',
    '.object-tools a:has-text("Delete")',
    '.submit-row a.deletelink',
    '.deletelink-box a',
    '#content a[href$="/delete/"]',
    'a[href$="/delete/"]',
  ];
  let clickedDelete = false;
  for (const sel of deleteCandidates) {
    const link = page.locator(sel).first();
    if (await link.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), link.click() ]);
      clickedDelete = true; break;
    }
  }
  if (!clickedDelete) {
    const u = new URL(page.url());
    if (!u.pathname.endsWith('/delete/')) {
      const forced = (u.origin + u.pathname.replace(/\/change\/?$/, '/') + 'delete/');
      await page.goto(forced, { waitUntil: 'domcontentloaded' }).catch(()=>{});
      clickedDelete = /\/delete\/?$/.test(page.url());
    }
  }
  expect(clickedDelete, 'Delete linki bulunamadı').toBeTruthy();

  // 5) Onay formu + çok dilli butonlar
  const confirmForm = page.locator('#content form:has(input[name="post"])').first()
                     .or(page.locator('form[action$="/delete/"]').first())
                     .or(page.locator('form:has(button[type="submit"]), form:has(input[type="submit"])').first());
  await expect(confirmForm, 'Delete onay formu yok').toBeVisible();

  const yesTexts = [
    /^Yes, I'?m sure$/i,
    /^Evet, eminim$/i,
    /^Sí, estoy segur(?:o|a)$/i,   // ← DÜZELTİLDİ
    /^Ja$/i, /^Oui$/i, /^Sì$/i
  ];
  let clickedConfirm = false;
  for (const rx of yesTexts) {
    const btn = page.getByRole('button', { name: rx }).first();
    if (await btn.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), btn.click() ]);
      clickedConfirm = true; break;
    }
    const fallbackBtn = confirmForm.locator('button[type="submit"], input[type="submit"]').filter({ hasText: rx }).first();
    if (await fallbackBtn.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), fallbackBtn.click() ]);
      clickedConfirm = true; break;
    }
  }
  if (!clickedConfirm) {
    const fallbackSubmit = confirmForm.locator('button[type="submit"], input[type="submit"]').first();
    await Promise.all([ page.waitForLoadState('domcontentloaded'), fallbackSubmit.click() ]);
  }

  // 6) Silme sonrası liste
  await expect(page).toHaveURL(new RegExp('/admin/maintenance/equipment/?$'));

  try { fs.writeFileSync('test-results/e104_debug_last.html', await page.content()); } catch {}
});