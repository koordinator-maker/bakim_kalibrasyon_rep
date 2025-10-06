// tests/admin-dashboard.spec.js
import { test, expect } from "@playwright/test";

test.describe("Admin Dashboard Tests", () => {
    test("should access admin panel", async ({ page }) => {
        const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

        await page.goto(`${BASE}/admin/`, { waitUntil: "domcontentloaded" });

        // Login sayfas�na redirect olmamal�
        await expect(page).not.toHaveURL(/\/admin\/login/);

        // Admin panel i�eri�i g�rmeli
        await expect(page.getByRole('main')).toBeVisible({ timeout: 5000 });

        console.log("[TEST PASSED] Authenticated admin access verified");
    });

    test("should list users in admin", async ({ page }) => {
        const BASE = (process.env.BASE_URL || "http://127.0.0.1:8010").replace(/\/$/, "");

        await page.goto(`${BASE}/admin/accounts/customuser/`, { waitUntil: "domcontentloaded" });

        // User listesi tablosu g�r�nmeli
        await expect(page.getByRole('main')).toBeVisible({ timeout: 5000 });

        console.log("[TEST PASSED] User list accessible");
    });
});







