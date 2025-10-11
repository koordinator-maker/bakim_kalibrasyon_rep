const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
const USER = process.env.ADMIN_USER || "admin";
const PASS = process.env.ADMIN_PASS || "admin123!";

async function loginIfNeeded(page){
  await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded" });
  if (/\/login\//i.test(page.url())) {
    await page.fill('input[name="username"]', USER).catch(()=>{});
    await page.fill('input[name="password"]', PASS).catch(()=>{});
    await Promise.all([
      page.waitForLoadState("domcontentloaded"),
      page.locator('input[type="submit"], button[type="submit"]').first().click()
    ]);
  }
  return page;
}
export async function ensureLogin(page){ return loginIfNeeded(page); }

export async function gotoList(page){
  page = await ensureLogin(page);
  const url = `${BASE}/admin/maintenance/equipment/`;
  for (let i=0;i<4;i++){
    await page.goto(url, { waitUntil: "domcontentloaded" });
    const title = (await page.title().catch(()=>'')) || '';
    const ok = await page.locator('#result_list, #changelist').count();
    if (ok > 0 && !/OperationalError/i.test(title)) return page;
    await page.waitForTimeout(500);
  }
  return page;
}

export async function gotoAdd(page){
  page = await ensureLogin(page);
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });
  return page;
}

export async function fillAllRequired(page){
  // Öncelik: code/name boşsa doldur
  for (const sel of ['#id_code','input[name="code"]','#id_name','input[name="name"]']){
    const el = page.locator(sel).first();
    if (await el.count()){
      const v = (await el.inputValue().catch(()=>'')) || '';
      if (!v) await el.fill(`AUTO_${Date.now()}`).catch(()=>{});
    }
  }
  // required alanlar
  const req = page.locator('input[required]:not([type="hidden"]):not([type="submit"]), textarea[required], select[required]');
  const n = await req.count();
  for (let i=0;i<n;i++){
    const el = req.nth(i);
    const tag = await el.evaluate(e => e.tagName.toLowerCase());
    const type = (await el.getAttribute('type')) || '';
    if (tag === 'select'){
      const options = await el.locator('option').all();
      for (const opt of options){
        const v = await opt.getAttribute('value');
        if (v && v !== '' && v !== '__None'){ await el.selectOption(v).catch(()=>{}); break; }
      }
    } else if (type === 'checkbox'){
      await el.check({ force:true }).catch(()=>{});
    } else {
      const cur = await el.inputValue().catch(()=> '');
      if (!cur) await el.fill('auto').catch(()=>{});
    }
  }
}

export async function save(page){
  const submit = page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first();
  await Promise.all([ page.waitForLoadState("domcontentloaded"), submit.click() ]);
}

export async function createMinimalEquipment(page){
  page = await gotoAdd(page);
  await page.locator('#id_code, input[name="code"]').first().fill(`C-${Date.now()}`).catch(()=>{});
  await page.locator('#id_name, input[name="name"], input[id*="name"]').first().fill(`EQ-${Date.now()}`).catch(()=>{});
  await fillAllRequired(page);
  await save(page);
  if (/\/add\/?$/i.test(page.url())){ // validation takılırsa bir tur daha
    await fillAllRequired(page);
    await save(page);
  }
  return page;
}

export async function successFlashExists(page){
  const s = ['ul.messagelist li.success', '.alert-success', '.messagelist .success', '[class*="success"]', 'div.success'];
  for (const sel of s){ if (await page.locator(sel).first().count() > 0) return true; }
  return false;
}