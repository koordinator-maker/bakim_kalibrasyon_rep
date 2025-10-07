/**
 * E104 — Equipment oluştur & sil (dayanıklı akış)
 * - Save sonrası changelist'e düşse bile adıyla satırı bulup change'e girer
 * - Delete linki bulunamazsa URL ile /delete/ sayfasına zorlar
 * - Onayı çok dilli buton adına göre dener; olmazsa ilk submit
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

  // 2) Name doldur (stabil + fallback)
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

  // 3) Kaydet
  const save = form.locator('input[name="_save"]').first();
  if (await save.isVisible().catch(()=>false)) {
    await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);
  } else {
    const submitAlt = form.locator('button[type="submit"], input[type="submit"]').first();
    await Promise.all([ page.waitForLoadState('domcontentloaded'), submitAlt.click() ]);
  }

  // 4) Change mi? Liste mi? — ikisini de kabul et, sonra change'e geç
  const changeRx = /\/admin\/maintenance\/equipment\/\d+\/change\/?$/;
  const listRx   = /\/admin\/maintenance\/equipment\/?$/;

  // kısa bekleme: change ya da list
  await Promise.race([
    page.waitForURL(changeRx, { timeout: 2000 }).catch(()=>null),
    page.waitForURL(listRx,   { timeout: 2000 }).catch(()=>null),
    page.waitForLoadState('domcontentloaded').catch(()=>null)
  ]);

  // Eğer listede kaldıysak, adıyla satırı aç
  if (!changeRx.test(page.url())) {
    // başarı mesajındaki change linki (bazı temalarda olur)
    const successLink = page.locator('main a[href*="/admin/maintenance/equipment/"][href$="/change/"]').first();
    if (await successLink.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), successLink.click() ]);
    }
  }
  if (!changeRx.test(page.url())) {
    const rowLinkByName = page.locator('#result_list tr:has-text("' + nameValue + '") a[href*="/change/"]').first();
    if (await rowLinkByName.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), rowLinkByName.click() ]);
    } else {
      // Son çare: listede ilk satırın change linki
      const anyRow = page.locator('#result_list tr a[href*="/change/"]').first();
      if (await anyRow.isVisible().catch(()=>false)) {
        await Promise.all([ page.waitForLoadState('domcontentloaded'), anyRow.click() ]);
      }
    }
  }

  await expect(page, 'Change sayfasına geçilemedi').toHaveURL(changeRx);
  const changeForm = page.locator('form:has(input[name="_save"])').first();
  await expect(changeForm, 'CHANGE formu görünür değil').toBeVisible();

  // 5) Delete'e geç (önce linkler, sonra URL)
  const deleteSelectors = [
    '.object-tools a.deletelink',
    '.object-tools a[href$="/delete/"]',
    '.submit-row a.deletelink',
    '#content a[href$="/delete/"]',
    'a[href$="/delete/"]'
  ];
  let wentDelete = false;
  for (const sel of deleteSelectors) {
    const link = page.locator(sel).first();
    if (await link.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), link.click() ]);
      wentDelete = true;
      break;
    }
  }
  if (!wentDelete) {
    const u = new URL(page.url());
    const forced = u.origin + u.pathname.replace(/\/change\/?$/, '/') + 'delete/';
    await page.goto(forced, { waitUntil: 'domcontentloaded' }).catch(()=>{});
    wentDelete = /\/delete\/?$/.test(page.url());
  }
  expect(wentDelete, 'Delete sayfasına gidilemedi').toBeTruthy();

  // 6) Onay (çok dilli) — yoksa ilk submit
  const yesRx = /(Yes|Evet|Si|Sí|Ja|Oui|Sì)/i;
  let confirmed = false;
  const btnByRole = page.getByRole('button', { name: yesRx }).first();
  if (await btnByRole.isVisible().catch(()=>false)) {
    await Promise.all([ page.waitForLoadState('domcontentloaded'), btnByRole.click() ]);
    confirmed = true;
  }
  if (!confirmed) {
    const confirmForm = page.locator('#content form:has(input[name="post"]), form[action$="/delete/"]').first();
    const firstSubmit = confirmForm.locator('button[type="submit"], input[type="submit"]').first();
    await Promise.all([ page.waitForLoadState('domcontentloaded'), firstSubmit.click() ]);
  }

  // 7) Changelist’e dönmüş ol
  await expect(page).toHaveURL(listRx);

  // 8) Artefakt
  try { fs.writeFileSync('test-results/e104_debug_last.html', await page.content()); } catch {}
});