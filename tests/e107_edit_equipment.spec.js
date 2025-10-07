import { test, expect } from '@playwright/test';
import { createTempEquipment, loginIfNeeded } from './helpers_e10x.js';

test('E107 - Ekipmanı düzenle ve kaydet', async ({ page }) => {
  const { page: p, token } = await createTempEquipment(page, `EDIT-${Date.now()}`);
  
  // Sayfa durumunu kontrol et
  console.log('📍 Sayfa URL (kayıt sonrası):', p.url());
  await p.screenshot({ path: 'debug_e107_after_create.png', fullPage: true });
  
  // Name field'ını bul ve değiştir
  const nameField = p.locator('#id_name');
  const isVisible = await nameField.isVisible().catch(() => false);
  console.log(`🔍 Name field görünür mü: ${isVisible}`);
  
  if (!isVisible) {
    const html = await p.content();
    console.log('📄 HTML snippet:', html.substring(0, 500));
    throw new Error('Name field bulunamadı - sayfa yanlış');
  }
  
  await nameField.fill(`EDITED-${token}`);
  
  // Kaydet butonuna tıkla
  console.log('💾 Kaydet butonuna tıklanıyor...');
  const saveButton = p.locator('input[name="_save"], button[name="_save"]').first();
  await saveButton.click();
  
  // Sayfa yüklenene kadar bekle
  await p.waitForLoadState('domcontentloaded');
  
  // Kayıt sonrası URL
  const finalUrl = p.url();
  console.log('📍 Kayıt sonrası URL:', finalUrl);
  
  // Screenshot
  await p.screenshot({ path: 'debug_e107_after_save.png', fullPage: true });
  
  // Success mesajı ara (farklı selector'lar)
  const successSelectors = [
    'ul.messagelist li.success',
    '.success',
    '.messagelist .success',
    '[class*="success"]',
    'div.success',
    '.alert-success'
  ];
  
  let foundSuccess = false;
  for (const sel of successSelectors) {
    const exists = await p.locator(sel).count() > 0;
    console.log(`  - ${sel}: ${exists ? '✓ var' : '✗ yok'}`);
    if (exists) {
      foundSuccess = true;
      const text = await p.locator(sel).first().textContent();
      console.log(`    Mesaj: "${text}"`);
      break;
    }
  }
  
  if (!foundSuccess) {
    console.error('❌ Hiçbir success selector bulunamadı');
    
    // Tüm class'ları listele
    const allClasses = await p.evaluate(() => {
      const classes = new Set();
      document.querySelectorAll('*').forEach(el => {
        el.classList.forEach(c => classes.add(c));
      });
      return Array.from(classes).filter(c => c.includes('message') || c.includes('success') || c.includes('alert'));
    });
    console.log('📋 Sayfadaki mesaj/success class\'ları:', allClasses);
  }
  
  // Test assertion
  expect(foundSuccess, 'Success mesajı bulunamadı').toBeTruthy();
});
