const BASE = process.env.BASE_URL || 'http://127.0.0.1:8010';
const USER = process.env.ADMIN_USER || 'admin';
const PASS = process.env.ADMIN_PASS || 'admin';

export async function ensureAlivePage(page) {
  if (!page || page.isClosed()) {
    throw new Error('Page is closed or invalid');
  }
  return page;
}

export async function loginIfNeeded(page) {
  page = await ensureAlivePage(page);
  
  // Admin login sayfasına git
  await page.goto(`${BASE}/admin/login/`, { 
    waitUntil: 'domcontentloaded',
    timeout: 10000
  });
  
  // Zaten login ise atla
  const url = page.url();
  if (!/\/login\//i.test(url)) {
    console.log('✅ Zaten login olunmuş');
    return page;
  }
  
  // Login formunu doldur
  console.log('🔐 Login yapılıyor...');
  
  try {
    await page.waitForSelector('#id_username', { timeout: 5000 });
    await page.fill('#id_username', USER);
    await page.fill('#id_password', PASS);
    
    // Submit butonuna tıkla
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 10000 }),
      page.locator('input[type="submit"]').first().click()
    ]);
    
    // Login başarılı mı kontrol et
    const finalUrl = page.url();
    if (/\/login\//i.test(finalUrl)) {
      throw new Error('Login başarısız - hala login sayfasında');
    }
    
    console.log('✅ Login başarılı:', finalUrl);
    return page;
    
  } catch (error) {
    console.error('❌ Login hatası:', error.message);
    await page.screenshot({ path: 'debug_login_error.png', fullPage: true });
    throw error;
  }
}

export async function gotoListExport(page) {
  page = await ensureAlivePage(page);
  
  await page.goto(`${BASE}/admin/maintenance/equipment/`, { 
    waitUntil: 'domcontentloaded',
    timeout: 10000
  });
  
  // Sayfa yüklenene kadar bekle
  await page.waitForLoadState('networkidle');
  
  // Login redirect kontrolü
  const url = page.url();
  if (/\/login\//i.test(url)) {
    console.log('⚠️  Equipment sayfası login gerektiriyor, yeniden login...');
    await loginIfNeeded(page);
    await page.goto(`${BASE}/admin/maintenance/equipment/`, { 
      waitUntil: 'domcontentloaded' 
    });
  }
  
  console.log('✅ Equipment listesi yüklendi:', page.url());
  return page;
}
