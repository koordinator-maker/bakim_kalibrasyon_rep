// Rev: 2025-10-02 13:05 r1
// playwright.config.js
const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  timeout: 30000,
  reporter: [["list"]],
  use: {
    baseURL: process.env.BASE_URL || "http://127.0.0.1:8010",
    headless: true,
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },
  projects: [
    {
      name: "setup",
      testMatch: /_setup\.spec\.js$/,
    },
    {
      name: "e2e",
      testMatch: /.*\.spec\.js$/,
      // setup projesi bitmeden koşma
      dependencies: ["setup"],
      use: {
        // setup'ın ürettiği oturum durumu
        storageState: "storage/user.json",
      },
    },
  ],
  // setup projesinin _setup.spec.js dışındaki testleri almasını engelle
  // e2e projesi ise tüm .spec.js dosyalarını alır ama _setup.spec.js zaten setup projesine ait.
});
