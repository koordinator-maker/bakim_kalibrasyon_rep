import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
test.use({ storageState: 'storage/user.json' });
test.setTimeout(45000);

test('E102 - Equipment Ekleme Formuna Erişim (debug)', async ({ page }) => {
  const addURL = `${BASE}/admin/maintenance/equipment/add/`;
  console.log('>>> goto', addURL);
  const resp = await page.goto(addURL, { waitUntil: 'domcontentloaded' });
  console.log('>>> nav status:', resp?.status(), 'final:', resp?.url());
  console.log('>>> url now:', page.url());

  const body = page.locator('body');
  const bodyClass = await body.getAttribute('class');
  console.log('>>> body.class:', bodyClass);

  // Listeye düştüysek Add butonundan ilerle
  if (!/\/add\/?$/.test(page.url()) || /change\-list/.test(bodyClass || '')) {
    const addLink = page.locator('a.addlink, .object-tools a[href$="/add/"]');
    const cnt = await addLink.count();
    console.log('>>> on list? addLink count:', cnt);
    if (cnt > 0) {
      await addLink.first().click();
      await page.waitForLoadState('domcontentloaded');
      console.log('>>> after click url:', page.url());
    }
  }

  await expect(page).toHaveURL(/\/add\/?$/);

  // Formu birkaç farklı seçiciyle ara
  const selectors = [
    'form[action*="/add/"]',
    '#content-main form',
    '#content form',
    'main form',
    'body form'
  ];
  let form = null, found = false;
  for (const sel of selectors) {
    const loc = page.locator(sel);
    if (await loc.count()) { form = loc; found = true; break; }
  }

  const h1 = await page.locator('#content h1, main h1, h1').first().textContent().catch(()=>null);
  console.log('>>> h1:', h1);
  console.log('>>> hasForm:', found);

  if (!found) {
    await page.screenshot({ path: 'test-results/E102-debug.png', fullPage: true });
    const html = await page.content();
    const fs = require('fs'); fs.mkdirSync('test-results', { recursive: true }); fs.writeFileSync('test-results/E102-debug.html', html);
  }

  expect(found, 'Form bulunamadı — test-results/E102-debug.html & E102-debug.png dosyalarına bak.').toBeTruthy();

  const saveBtn = page.locator("button[name*='_save'], input[name*='_save'], button[type='submit'], input[type='submit']");
  await expect(saveBtn).toBeVisible();
});