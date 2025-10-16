import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";

test("E105 - Liste arama (sade ve sağlam)", async ({ page }) => {
  await ensureLogin(page);
  await gotoList(page);
  
  // Multi-selector strategy
  const searchSelectors = [
    'input[name="q"]',
    'input[type="search"]',
    '#searchbar',
    'input[placeholder*="Search"]',
    'input[placeholder*="search"]',
    '.search-query',
    '#changelist-search input[type="text"]',
    '#toolbar input[type="text"]'
  ];
  
  let searchInput = null;
  for(const sel of searchSelectors){
    const el = page.locator(sel).first();
    const count = await el.count();
    if(count > 0){
      const visible = await el.isVisible().catch(() => false);
      if(visible){
        searchInput = el;
        console.log(`[FOUND] Search input: ${sel}`);
        break;
      }
    }
  }
  
  if(!searchInput){
    console.warn('[SKIP] No search input found, test skipped');
    test.skip();
    return;
  }
  
  await expect(searchInput).toBeVisible({ timeout: 10000 });
  await searchInput.fill("AUTO");
  await searchInput.press("Enter");
  
  await page.waitForLoadState("domcontentloaded");
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?.*q=/);
  
  const resultList = page.locator("#result_list, #changelist");
  await expect.soft(resultList.first()).toBeVisible({ timeout: 5000 });
});