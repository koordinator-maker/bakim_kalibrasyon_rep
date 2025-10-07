module.exports.loginAdmin = async function loginAdmin(page, baseURL, user, pass) {
  const root = (baseURL || "http://127.0.0.1:8010").replace(/\/$/, "");
  // 0) Logout ile tertemiz başla
  await page.goto(root + "/admin/logout/", { waitUntil: "domcontentloaded" }).catch(()=>{});

  // 1) Login sayfasına (next'siz) git
  await page.goto(root + "/admin/login/", { waitUntil: "domcontentloaded" });

  // Zaten login'liysen çık
  if (!/\/admin\/login\//.test(page.url())) return;

  // 2) Kullanıcı/şifre alanlarını id/name/placeholder/label ile bul
  // Kullanıcı
  let u = page.locator("#id_username, input[name='username'], input[name='email'], input#id_user, input[name='user']").first();
  const uByPh = page.getByPlaceholder(/kullanıcı adı|kullanici adi|email|e-?posta|username/i).first();
  const uByLb = page.getByLabel(/kullanıcı adı|kullanici adi|username|email|e-?posta/i).first();
  if (!(await u.isVisible().catch(()=>false))) u = (await uByPh.isVisible().catch(()=>false)) ? uByPh : uByLb;

  // Parola
  let p = page.locator("#id_password, input[name='password'], input[type='password']").first();
  const pByPh = page.getByPlaceholder(/parola|şifre|sifre|password/i).first();
  const pByLb = page.getByLabel(/parola|şifre|sifre|password/i).first();
  if (!(await p.isVisible().catch(()=>false))) p = (await pByPh.isVisible().catch(()=>false)) ? pByPh : pByLb;

  // 3) Alanları bekle ve doldur
  await u.waitFor({ state: "visible", timeout: 15000 });
  await p.waitFor({ state: "visible", timeout: 15000 });
  await u.fill(user, { timeout: 10000 });
  await p.fill(pass, { timeout: 10000 });

  // 4) Submit: buton veya Enter fallback
  const btn = page.getByRole("button", { name: /log in|giriş|oturum|sign in|submit|login/i }).first();
  if (await btn.isVisible().catch(()=>false)) {
    await btn.click();
  } else {
    const submit = page.locator("input[type='submit'], button[type='submit']").first();
    if (await submit.isVisible().catch(()=>false)) {
      await submit.click();
    } else {
      await p.press("Enter");
    }
  }

  // 5) Başarı teyidi
  await page.waitForLoadState("domcontentloaded").catch(()=>{});
  await page.waitForTimeout(300); // anlık redirect'leri yakalamak için minik bekleme
  if (/\/admin\/login\//.test(page.url())) {
    // Bazı temalarda next query gereksiz yere kalabiliyor; köke zorluyoruz
    await page.goto(root + "/admin/", { waitUntil: "domcontentloaded" }).catch(()=>{});
  }
};