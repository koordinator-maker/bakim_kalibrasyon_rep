export async function loginAdmin(page, baseURL, user, pass) {
  const root = (baseURL || "http://127.0.0.1:8010").replace(/\/$/, "");
  const loginUrl = root + "/admin/login/?next=/admin/maintenance/equipment/add/";

  // 1) Login sayfasına git
  await page.goto(loginUrl, { waitUntil: "domcontentloaded" });

  // Zaten login'liysek çık
  if (!/\/admin\/login\//.test(page.url())) return;

  // 2) Kullanıcı adı / parola: id + name + label fallback
  const userSel = "#id_username, input[name='username'], input#id_user, input[name='user'], input[name='email']";
  const passSel = "#id_password, input[name='password'], input[type='password']";

  const uByLabel = page.getByLabel(/Kullanıcı adı|Kullanici adi|Username/i).first();
  const pByLabel = page.getByLabel(/Parola|Şifre|Sifre|Password/i).first();

  let u = page.locator(userSel).first();
  if (!(await u.isVisible().catch(()=>false))) u = uByLabel;

  let p = page.locator(passSel).first();
  if (!(await p.isVisible().catch(()=>false))) p = pByLabel;

  await u.fill(user, { timeout: 5000 }).catch(()=>{});
  await p.fill(pass, { timeout: 5000 }).catch(()=>{});

  // 3) Gönder
  const btn = page.getByRole("button", { name: /Log in|Giriş|Oturum|Sign in|Submit|Login/i }).first();
  if (await btn.isVisible().catch(()=>false)) {
    await btn.click();
  } else {
    await page.locator("input[type='submit'], button[type='submit']").first().click().catch(()=>{});
  }

  // 4) Login tamam mı? Değilse /admin/ köküne zorla
  await page.waitForLoadState("domcontentloaded").catch(()=>{});
  if (/\/admin\/login\//.test(page.url())) {
    await page.goto(root + "/admin/", { waitUntil: "domcontentloaded" }).catch(()=>{});
  }
}