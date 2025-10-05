import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(45000);

async function goToAdd(page) {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  if (!/\/add\/?$/.test(page.url())) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    if (await addLink.count()) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
    }
  }
}

async function ensureOnChangePage(page, ts, primaryText) {
  if (/\/change\/?$/.test(page.url())) return true;

  const msgChange = page.locator('ul.messagelist a[href*="/change/"]');
  if (await msgChange.count()) {
    await msgChange.first().click();
    await page.waitForLoadState('domcontentloaded');
    if (/\/change\/?$/.test(page.url())) return true;
  }

  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: 'domcontentloaded' });
  let row = page.locator(`#result_list a:has-text("${ts}")`);
  if (!(await row.count()) && primaryText) {
    row = page.locator(`#result_list a:has-text("${primaryText}")`);
  }
  if (await row.count()) {
    await row.first().click();
    await page.waitForLoadState('domcontentloaded');
    return /\/change\/?$/.test(page.url());
  }
  return false;
}

test('E104 - Equipment oluştur ve sil (temizlik)', async ({ page }) => {
  await goToAdd(page);

  const form = page.locator('form:has(input[name="_save"])').first();
  await expect(form).toBeVisible();

  const ts = Date.now().toString();
  let primaryText = null;

  for (const sel of ['input[required][type="text"]','input[required]:not([type])','textarea[required]']) {
    const inputs = form.locator(sel);
    for (let i = 0; i < await inputs.count(); i++) {
      const el = inputs.nth(i);
      const name = (await el.getAttribute('name')) || `text${i}`;
      const val = name.toLowerCase().includes('serial') ? `SN-${ts}` : `AUTO-${name}-${ts}`;
      await el.fill(val);
      if (!primaryText) primaryText = val;
    }
  }

  const nums = form.locator('input[required][type="number"]');
  for (let i = 0; i < await nums.count(); i++) await nums.nth(i).fill('0');

  const today = new Date().toISOString().slice(0,10);
  const dates = form.locator('input[required][type="date"]');
  for (let i = 0; i < await dates.count(); i++) await dates.nth(i).fill(today);

  const selects = form.locator('select[required]');
  for (let i = 0; i < await selects.count(); i++) {
    await selects.nth(i).selectOption({ index: 1 }).catch(() => {});
  }

  await form.locator('input[name="_save"]').click();

  const onChange = await ensureOnChangePage(page, ts, primaryText);
  expect(onChange, 'Kayıt sonrası change sayfasına ulaşılamadı.').toBeTruthy();

  // Silme sayfasına git
  const deleteURL = page.url().replace(/change\/?$/, 'delete/');
  await page.goto(deleteURL, { waitUntil: 'domcontentloaded' });

  // YALNIZCA silme onay formu (içinde name="post" bulunur)
  const delForm = page.locator('#content form:has(input[name="post"])').first();
  await expect(delForm).toBeVisible();

  // Form içindeki submit
  await delForm.locator('input[type="submit"], button[type="submit"]').first().click();

  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/$/);
  await expect(page.locator('ul.messagelist li.success, .success')).toBeVisible();
});