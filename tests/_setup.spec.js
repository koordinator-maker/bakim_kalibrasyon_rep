// tests/_setup.spec.js
// Enhanced with debugging and multiple selector strategies

const { test: setup } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

const BASE = process.env.BASE_URL || "http://127.0.0.1:8010";
const USER = process.env.ADMIN_USER || "hp";
const PASS = process.env.ADMIN_PASS || "A1234";

setup("login state -> storage/user.json", async ({ page }) => {
  console.log(`\n🔍 DEBUG: Starting login flow...`);
  console.log(`   BASE_URL: ${BASE}`);
  console.log(`   USERNAME: ${USER}`);
  
  // 1) Navigate with extended timeout
  console.log(`\n📍 Navigating to: ${BASE}/accounts/login/`);
  await page.goto(`${BASE}/accounts/login/`, { 
    waitUntil: "networkidle",
    timeout: 15000 
  });
  
  const currentUrl = page.url();
  console.log(`   Current URL: ${currentUrl}`);
  
  // 2) Take debug screenshot
  const debugDir = path.resolve("test-results", "debug");
  fs.mkdirSync(debugDir, { recursive: true });
  const screenshotPath = path.join(debugDir, "01-login-page.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`   📸 Screenshot saved: ${screenshotPath}`);
  
  // 3) Log page content for debugging
  const title = await page.title();
  console.log(`   Page title: "${title}"`);
  
  const bodyText = await page.locator("body").textContent();
  console.log(`   Page contains "login": ${bodyText.toLowerCase().includes("login")}`);
  console.log(`   Page contains "username": ${bodyText.toLowerCase().includes("username")}`);
  
  // 4) Try multiple selector strategies
  console.log(`\n🔎 Searching for login fields...`);
  
  let userInput, passInput, submitBtn;
  
  // Strategy 1: Common name attributes
  try {
    userInput = page.locator('input[name="username"]').first();
    await userInput.waitFor({ timeout: 2000 });
    console.log(`   ✓ Found username via: input[name="username"]`);
  } catch {
    console.log(`   ✗ Failed: input[name="username"]`);
  }
  
  // Strategy 2: ID attributes
  if (!userInput) {
    try {
      userInput = page.locator('#id_username, #username').first();
      await userInput.waitFor({ timeout: 2000 });
      console.log(`   ✓ Found username via: #id_username`);
    } catch {
      console.log(`   ✗ Failed: #id_username`);
    }
  }
  
  // Strategy 3: Type attribute
  if (!userInput) {
    try {
      userInput = page.locator('input[type="text"]').first();
      await userInput.waitFor({ timeout: 2000 });
      console.log(`   ✓ Found username via: input[type="text"]`);
    } catch {
      console.log(`   ✗ Failed: input[type="text"]`);
    }
  }
  
  // Find password field
  try {
    passInput = page.locator('input[name="password"], #id_password, input[type="password"]').first();
    await passInput.waitFor({ timeout: 2000 });
    console.log(`   ✓ Found password field`);
  } catch (err) {
    console.log(`   ✗ Failed to find password field`);
    throw new Error(`Password field not found. Page might not be a login page.`);
  }
  
  // Find submit button
  try {
    submitBtn = page.locator('button[type="submit"], input[type="submit"], button:has-text("giriş"), button:has-text("login")').first();
    await submitBtn.waitFor({ timeout: 2000 });
    console.log(`   ✓ Found submit button`);
  } catch {
    console.log(`   ⚠ Submit button not found, will try Enter key`);
  }
  
  if (!userInput) {
    // Dump all input fields for debugging
    const allInputs = await page.locator('input').all();
    console.log(`\n📋 All input fields found on page (${allInputs.length}):`);
    for (let i = 0; i < Math.min(allInputs.length, 10); i++) {
      const input = allInputs[i];
      const name = await input.getAttribute('name');
      const id = await input.getAttribute('id');
      const type = await input.getAttribute('type');
      console.log(`   ${i + 1}. name="${name}" id="${id}" type="${type}"`);
    }
    
    throw new Error(`❌ Could not find username field with any strategy. Check screenshot at: ${screenshotPath}`);
  }
  
  // 5) Perform login
  console.log(`\n🔐 Attempting login...`);
  await userInput.fill(USER);
  await passInput.fill(PASS);
  
  await page.screenshot({ path: path.join(debugDir, "02-filled-form.png") });
  console.log(`   📸 Form filled screenshot saved`);
  
  if (submitBtn) {
    await submitBtn.click();
  } else {
    await passInput.press("Enter");
  }
  
  // Wait for navigation
  await page.waitForLoadState("networkidle", { timeout: 10000 });
  
  await page.screenshot({ path: path.join(debugDir, "03-after-login.png") });
  console.log(`   📸 After login screenshot saved`);
  
  // 6) Save auth state
  const storageDir = path.resolve("storage");
  fs.mkdirSync(storageDir, { recursive: true });
  await page.context().storageState({ path: path.join(storageDir, "user.json") });
  
  console.log(`✓ Login successful! Auth state saved to: storage/user.json\n`);
});