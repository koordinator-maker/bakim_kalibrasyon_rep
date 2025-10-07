/**
 * Rev: 2025-10-06 12:28 r1
 * E104 — Equipment oluştur & sil (stabil seçiciler, auto-login fallback)
 */
import { test, expect } from '@playwright/test';
import fs from 'fs';

test('E104 - Equipment oluştur ve sil (temizlik)', async ({ page }) => {
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

  // 0) Login garantile
  await loginIfNeeded();

  // 1) ADD formuna git
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });

  // 2) Kaydet butonlu formu bekle
  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form).toBeVisible();

  // 3) İsim alanını kesin doldur (probe çıktısına göre)
  const ts = Date.now().toString();
  const nameValue = 'AUTO-NAME-' + ts;
  const nameSelectors = ['input[name="name"]', '#id_name'];
  let filledName = false;
  for (const sel of nameSelectors) {
    const f = form.locator(sel).first();
    if (await f.isVisible().catch(()=>false)) {
      await f.fill(nameValue);
      filledName = true;
      break;
    }
  }
  if (!filledName) {
    // Son çare: ilk görünür text input/textarea
    const cand = form.locator('input[type="text"], input:not([type]), textarea').first();
    if (await cand.isVisible().catch(()=>false)) {
      await cand.fill(nameValue);
      filledName = true;
    }
  }
  expect(filledName, 'Name-like alan bulunamadı').toBeTruthy();

  // 4) Kaydet
  const save = form.locator('input[name="_save"]').first();
  if (await save.isVisible().catch(()=>false)) {
    await Promise.all([ page.waitForLoadState('domcontentloaded'), save.click() ]);
  } else {
    const submitAlt = form.locator('button[type="submit"], input[type="submit"]').first();
    await Promise.all([ page.waitForLoadState('domcontentloaded'), submitAlt.click() ]);
  }

  // 5) Change sayfasına ulaştığımızı garanti et
  let onChange = /\/change\/?$/.test(page.url());
  if (!onChange) {
    const msgChange = page.locator('ul.messagelist a[href*="/change/"]').first();
    if (await msgChange.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), msgChange.click() ]);
      onChange = /\/change\/?$/.test(page.url());
    }
  }
  if (!onChange) {
    await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: 'domcontentloaded' });
    const rowLink = page.getByRole('row', { name: new RegExp(nameValue) }).locator('a').first();
    if (await rowLink.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), rowLink.click() ]);
      onChange = /\/change\/?$/.test(page.url());
    }
  }
  expect(onChange, 'Change sayfasına ulaşılamadı').toBeTruthy();

  // 6) Delete linkine git
  const deleteCandidates = [
    'a.deletelink',
    '.object-tools a.deletelink',
    'a#delete',
    'a:has-text("Delete")',
    'a:has-text("Sil")',
    'button:has-text("Delete")',
    'button:has-text("Sil")'
  ];
  let clickedDelete = false;
  for (const sel of deleteCandidates) {
    const el = page.locator(sel).first();
    if (await el.isVisible().catch(()=>false)) {
      await Promise.all([ page.waitForLoadState('domcontentloaded'), el.click() ]);
      clickedDelete = true;
      break;
    }
  }
  expect(clickedDelete, 'Delete linki bulunamadı').toBeTruthy();

  // 7) Onay formu (Django kalıbı)
  const confirmForm = page.locator('#content form:has(input[name="post"])').first()
                       .or(page.locator('form[action$="/delete/"]').first());
  await expect(confirmForm).toBeVisible();

  const confirmBtn = confirmForm.locator('input[type="submit"], button[type="submit"]').first();
  await Promise.all([ page.waitForLoadState('domcontentloaded'), confirmBtn.click() ]);

  // 8) Changelist ve/veya başarı mesajı
  await expect(page).toHaveURL(new RegExp('/admin/maintenance/equipment/?$'));
  await page.locator('.messagelist').textContent().catch(()=>{});
  
  // Artefakt: hata anında DOM’u bırakmak için
  try { fs.writeFileSync('test-results/e104_add_page.html', await page.content()); } catch {}
});