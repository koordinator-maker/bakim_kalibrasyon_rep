import { test, expect } from '@playwright/test';

const BASE = (process.env.BASE_URL || 'http://127.0.0.1:8010').replace(/\/$/, '');
const USER = process.env.ADMIN_USER || 'admin';
const PASS = process.env.ADMIN_PASS || 'admin';

test.setTimeout(60000);

async function loginIfNeeded(page) {
  await page.goto(`${BASE}/admin/`, { waitUntil: 'domcontentloaded' });
  if (!/\/admin\/login\//i.test(page.url())) return;
  await page.fill('#id_username', USER);
  await page.fill('#id_password', PASS);
  await Promise.all([
    page.waitForLoadState('domcontentloaded'),
    page.locator('input[type="submit"], button[type="submit"]').first().click(),
  ]);
  // stabilize
  await page.waitForLoadState('domcontentloaded');
}

async function ensureOnAdd(page) {
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  if (/\/admin\/login\//i.test(page.url())) {
    await loginIfNeeded(page);
    await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: 'domcontentloaded' });
  }
}

async function gotoList(page) {
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: 'domcontentloaded' });
  if (/\/admin\/login\//i.test(page.url())) {
    await loginIfNeeded(page);
    await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: 'domcontentloaded' });
  }
  await expect(page.locator('#changelist, .change-list, #content')).toBeVisible();
}

function formWithSubmit(page) {
  return page.locator('form').filter({
    has: page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]')
  }).first();
}

async function clickSaveAndStabilize(page, form) {
  const btn = form.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await btn.click();
  // Don't use waitForNavigation (caused context-close race). Instead, wait for any of below:
  // 1) success message appears OR
  // 2) URL becomes changelist or change page OR
  // 3) the page fully loads and submit becomes disabled (postback)
  const start = Date.now();
  const success = page.locator('ul.messagelist li.success, .success, .alert-success');
  while (Date.now() - start < 12000) {
    const url = page.url();
    if (/\/admin\/maintenance\/equipment\/(\d+\/change\/)?$/i.test(url)) return;
    if (await success.first().isVisible().catch(()=>false)) return;
    // minor idle
    await page.waitForTimeout(200);
  }
  // final fallback wait for load
  await page.waitForLoadState('domcontentloaded');
}

export async function createTempEquipment(page, token) {
  await ensureOnAdd(page);
  const form = formWithSubmit(page);
  await expect(form).toBeVisible();

  const ts = token || Date.now().toString();
  let primaryText = null;

  const textLike = form.locator('input[required][type="text"], input[required]:not([type]), textarea[required]');
  const countText = await textLike.count();
  if (countText === 0) {
    // fallback: try known fields
    const nm = page.locator('#id_name');
    if (await nm.isVisible().catch(()=>false)) { await nm.fill(`AUTO-name-${ts}`); primaryText = `AUTO-name-${ts}`; }
  } else {
    for (let i = 0; i < countText; i++) {
      const el = textLike.nth(i);
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

  await clickSaveAndStabilize(page, form);

  // If we saved and got redirected to changelist, open the created row via search
  if (/\/admin\/maintenance\/equipment\/?$/i.test(page.url())) {
    await page.fill('input[name="q"]', ts);
    await Promise.all([
      page.waitForLoadState('domcontentloaded'),
      page.press('input[name="q"]', 'Enter'),
    ]);
    const first = page.locator('#result_list tbody tr th a').first();
    if (await first.isVisible().catch(()=>false)) {
      await Promise.all([page.waitForLoadState('domcontentloaded'), first.click()]);
    }
  }
  return { token: ts, primaryText };
}

export async function ensureLogin(page) { await loginIfNeeded(page); }
export async function gotoListExport(page){ return gotoList(page); }
