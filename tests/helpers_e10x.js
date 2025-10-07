const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");
const USER = process.env.ADMIN_USER || "admin";
const PASS = process.env.ADMIN_PASS || "admin";

// KapalÄ± sayfa ise aynÄ± context'te taze sayfa aÃ§
export async function ensureAlivePage(page) {
  try { if (page && !page.isClosed()) return page; } catch {}
  const ctx = page.context();
  const fresh = await ctx.newPage();
  await fresh.waitForLoadState("domcontentloaded");
  return fresh;
}

export async function loginIfNeeded(page) {
  page = await ensureAlivePage(page);

  // Ã–nce /admin/ â€” zaten login isek burada kalÄ±rÄ±z
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

  // BaÅŸarÄ±lÄ± mÄ±?
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

// Basit ekipman oluşturucu: zorunlu alanı doldurup kaydeder
export async function createTempEquipment(page, token) {
  page = await loginIfNeeded(page);
  const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

  // Add formuna git
  await page.goto(`${BASE}/admin/maintenance/equipment/add/`, { waitUntil: "domcontentloaded" });

  // Zorunlu alan: name
  const ts = token || `AUTO-${Date.now()}`;
  await page.fill("#id_name", `AUTO-name-${ts}`);

  // Kaydet
  await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.locator('input[name="_save"], button[name="_save"], input[type="submit"], button[type="submit"]').first().click()
  ]);

  // Listeye döndüysek OK
  return { page, token: ts };
}