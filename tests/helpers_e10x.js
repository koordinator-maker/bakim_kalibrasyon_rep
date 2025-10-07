const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
const USER = process.env.ADMIN_USER || "admin";
const PASS = process.env.ADMIN_PASS || "admin";

// KapalÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â± sayfa ise aynÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â± context'te taze sayfa aÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§
export async function ensureAlivePage(page) {
  try { if (page && !page.isClosed()) return page; } catch {}
  const ctx = page.context();
  const fresh = await ctx.newPage();
  await fresh.waitForLoadState("domcontentloaded");
  return fresh;
}

export async function loginIfNeeded(page) {
  page = await ensureAlivePage(page);

  // ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“nce /admin/ ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â zaten login isek burada kalÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±rÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±z
  await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded" });
  if (!/\/admin\/login\//i.test(page.url())) return page;

  // Login formu
  await page.goto(`${BASE}/admin/login/`, { waitUntil: "domcontentloaded" });
  await page.fill("#id_username", USER);
  await page.fill("#id_password", PASS);
  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.locator('input[type="submit"], button[type="submit"]').first().click()
  ]);

  // BaÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€¦Ã‚Â¸arÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±lÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â± mÃƒÆ’Ã¢â‚¬ÂÃƒâ€šÃ‚Â±?
  if (/\/admin\/login\//i.test(page.url())) {
    const err = await page.locator(".errornote, .errorlist, .messages .error").first().innerText().catch(()=> "");
    throw new Error(`LOGIN_FAILED: url=${page.url()} msg=${err}`);
  }
  return page;
}

export async function gotoListExport(page) {
  page = await ensureAlivePage(page);
  const listUrl = `${BASE}/admin/maintenance/equipment/`;

  for (let i = 0; i < 3; i++) {
    await page.goto(listUrl, { waitUntil: "domcontentloaded" });

    if (/\/admin\/login\//i.test(page.url())) {
      page = await loginIfNeeded(page);
      continue;
    }
    const q = page.locator('input[name="q"]').first();
    const tbl = page.locator("#result_list").first();
    if (await q.isVisible().catch(()=>false) || await tbl.isVisible().catch(()=>false)) {
      return page;
    }
    await page.waitForTimeout(400);
  }

  let title = ""; try { title = await page.title(); } catch {}
  throw new Error(`Changelist not ready: url=${page.url()} title=${title}`);
}

export async function ensureLogin(page){ return loginIfNeeded(page); }

// Basit ekipman oluÃƒâ€¦Ã…Â¸turucu: zorunlu alanÃƒâ€Ã‚Â± doldurup kaydeder
export async function createTempEquipment(page, token) {
  page = await loginIfNeeded(page);
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  const ts = token || `AUTO-${Date.now()}`;
  await page.fill("#id_name", `AUTO-name-${ts}`);

  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.locator('input[name="_continue"], button[name="_continue"]').first().click()
  ]);

  // Eğer login'e düştüysek tekrar login ol
  if (/\/login\//i.test(page.url())) {
    await loginIfNeeded(page);
  }

  // Form alanını garanti bekle
  await page.waitForSelector("#id_name", { timeout: 15000 });
  return { page, token: ts };
}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // Zorunlu alan: name
  const ts = token || `AUTO-${Date.now()}`;
  await page.fill("#id_name", `AUTO-name-${ts}`);

  // Kaydet
  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.locator('input[name="_continue"], button[name="_continue"]').first().click()
  ]);

  // Listeye dÃƒÆ’Ã‚Â¶ndÃƒÆ’Ã‚Â¼ysek OK
  await page.waitForSelector('#id_name', { timeout: 10000 });
await page.waitForSelector('#id_name', { timeout: 10000 });
return { page, token: ts };
}