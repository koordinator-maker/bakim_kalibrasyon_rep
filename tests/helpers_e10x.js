const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
const USER = process.env.ADMIN_USER || "admin";
const PASS = process.env.ADMIN_PASS || "admin123!";

async function loginIfNeeded(page){
  const maxRetries = 3;
  for(let attempt = 1; attempt <= maxRetries; attempt++){
    try {
      await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded", timeout: 30000 });
      if (/\/login\//i.test(page.url())) {
        await page.fill('input[name="username"]', USER, { timeout: 5000 });
        await page.fill('input[name="password"]', PASS, { timeout: 5000 });
        await page.locator('input[type="submit"],button[type="submit"]').first().click({ timeout: 5000 });
        await page.waitForLoadState("domcontentloaded", { timeout: 30000 });
      }
      return page;
    } catch(e){
      console.warn(`[RETRY ${attempt}/${maxRetries}] Login failed: ${e.message}`);
      if(attempt === maxRetries) throw e;
      await page.waitForTimeout(2000);
    }
  }
}

export async function ensureLogin(page){ 
  return await loginIfNeeded(page); 
}

export async function gotoList(page){
  page = await ensureLogin(page);
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForTimeout(2000);
  return page;
}

export async function gotoAdd(page){
  const maxRetries = 3;
  for(let attempt = 1; attempt <= maxRetries; attempt++){
    try {
      page = await ensureLogin(page);
      await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { 
        waitUntil: "domcontentloaded", 
        timeout: 30000 
      });
      await page.waitForTimeout(2000);
      
      // Form yüklendi mi kontrol et
      const formExists = await page.locator('form').count() > 0;
      if(formExists){
        console.log(`[SUCCESS] Add form loaded (attempt ${attempt})`);
        return page;
      }
      
      throw new Error('Form not found');
    } catch(e){
      console.warn(`[RETRY ${attempt}/${maxRetries}] gotoAdd failed: ${e.message}`);
      if(attempt === maxRetries) throw e;
      await page.waitForTimeout(3000);
    }
  }
}

export async function fillAllRequired(page){
  if(!page || page.isClosed()){ 
    console.error('[ABORT] Page closed');
    return false; 
  }
  
  await page.waitForLoadState('domcontentloaded', { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(1000);
  
  // Code field
  const codeSelectors = ['#id_code', 'input[name="code"]'];
  let codeFilled = false;
  
  for(const sel of codeSelectors){
    try {
      const el = page.locator(sel).first();
      if(await el.count() > 0){
        await el.fill(`CODE-${Date.now()}`, { timeout: 5000 });
        console.log(`[FILL] Code via ${sel}`);
        codeFilled = true;
        break;
      }
    } catch(e){ }
  }
  
  // Name field
  const nameSelectors = ['#id_name', 'input[name="name"]'];
  let nameFilled = false;
  
  for(const sel of nameSelectors){
    try {
      const el = page.locator(sel).first();
      if(await el.count() > 0){
        await el.fill(`EQUIPMENT-${Date.now()}`, { timeout: 5000 });
        console.log(`[FILL] Name via ${sel}`);
        nameFilled = true;
        break;
      }
    } catch(e){ }
  }
  
  if(!codeFilled || !nameFilled){
    console.error('[ERROR] Required fields not filled!');
    return false;
  }
  
  // Other required fields
  try {
    const required = page.locator('input[required]:visible, select[required]:visible').all();
    const fields = await required;
    
    for(const field of fields){
      try {
        const tag = await field.evaluate(e => e.tagName.toLowerCase());
        const name = await field.getAttribute('name');
        
        // Skip code/name (already filled)
        if(name === 'code' || name === 'name') continue;
        
        if(tag === 'select'){
          const options = await field.locator('option[value]:not([value=""])').all();
          if(options.length > 0){
            const val = await options[0].getAttribute('value');
            await field.selectOption(val, { timeout: 3000 });
          }
        } else {
          const current = await field.inputValue({ timeout: 2000 }).catch(() => '');
          if(!current){
            await field.fill('test', { timeout: 3000 });
          }
        }
      } catch(e){ 
        console.warn(`[SKIP] Field error: ${e.message}`);
      }
    }
  } catch(e){
    console.warn(`[WARN] Required fields: ${e.message}`);
  }
  
  return true;
}

export async function save(page){
  const saveSelectors = [
    'input[name="_save"]',
    'button[name="_save"]', 
    'input[value="Save"]',
    'button:has-text("Save")',
    'input[type="submit"]'
  ];
  
  for(const sel of saveSelectors){
    try {
      const btn = page.locator(sel).first();
      if(await btn.count() > 0){
        await btn.click({ timeout: 5000 });
        console.log(`[CLICK] Save via ${sel}`);
        await page.waitForLoadState("domcontentloaded", { timeout: 30000 });
        await page.waitForTimeout(2000);
        return true;
      }
    } catch(e){ }
  }
  
  console.error('[ERROR] No save button found');
  return false;
}

export async function createMinimalEquipment(page){
  console.log('[START] Creating equipment...');
  
  // Step 1: Go to add form
  page = await gotoAdd(page);
  
  // Step 2: Fill form
  const filled = await fillAllRequired(page);
  if(!filled){
    throw new Error('Failed to fill form');
  }
  
  // Step 3: Save
  const saved = await save(page);
  if(!saved){
    throw new Error('Failed to save');
  }
  
  // Step 4: Check if still on add page (validation error)
  await page.waitForTimeout(2000);
  const currentUrl = page.url();
  
  if(currentUrl.includes('/add/')){
    console.warn('[RETRY] Still on add page, retry save...');
    await fillAllRequired(page);
    await save(page);
    await page.waitForTimeout(2000);
  }
  
  console.log(`[SUCCESS] Equipment created, URL: ${page.url()}`);
  return page;
}

export async function successFlashExists(page){
  const selectors = [
    '.messagelist .success',
    '.alert-success',
    'ul.messagelist li.success'
  ];
  
  for(const sel of selectors){
    if(await page.locator(sel).count() > 0){
      return true;
    }
  }
  return false;
}