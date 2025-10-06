const path = require("path");
/** @type {import("@playwright/test").PlaywrightTestConfig} */
module.exports = {
  testDir: "./tests",
  timeout: 30_000,
  globalSetup: path.resolve(__dirname, "tests/global.setup.cjs"),
  use: {
    baseURL: process.env.BASE_URL || "http://127.0.0.1:8010",
    storageState: path.resolve(__dirname, "tests/.auth/admin.json"),
    headless: true
  },
  projects: [
    { name: "chromium", use: { browserName: "chromium" } }
  ],
  testIgnore: ["tests/_setup.spec.js", "tests/**/_*.spec.*"],
  reporter: [["list"]]
};