/** @type {import("@playwright/test").PlaywrightTestConfig} */
const config = {
  globalSetup: "./tests/global.setup.cjs",
  use: {
    storageState: "./tests/.auth/admin.json",
    baseURL: process.env.BASE_URL || "http://127.0.0.1:8010",
  },
  reporter: [["line"], ["html"], ["blob"]],
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
};
module.exports = config;