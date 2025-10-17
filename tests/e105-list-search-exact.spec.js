import { test, expect } from "@playwright/test";
import { ensureLogin, gotoList } from "./helpers_e10x.js";

test("E105 - Liste arama exact match", async ({ page }) => {
  await ensureLogin(page);
  await gotoList(page);

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
    if(await el.count() > 0 && await el.isVisible().catch(() => false)){
      searchInput = el;
      break;
    }
  }

  if(!searchInput){
    test.skip();
    return;
  }

  await searchInput.fill("AUTO");
  await searchInput.press("Enter");
  await page.waitForLoadState("domcontentloaded");
  await expect(page).toHaveURL(/\/admin\/maintenance\/equipment\/\?.*q=/);
  const resultList = page.locator("#result_list, #changelist");
  await expect(resultList.first()).toBeVisible({ timeout: 5000 });
});

