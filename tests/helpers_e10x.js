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