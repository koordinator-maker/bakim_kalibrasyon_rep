import { test, expect } from "@playwright/test";
const entry = process.env.ENTRY_PATH || "/admin/";

// Yardımcı: aria-labelledby çöz
function labelledByText(el) {
  const id = el.getAttribute("aria-labelledby");
  if (!id) return "";
  return Array.from(id.split(/\s+/)).map(x => {
    const t = el.ownerDocument.getElementById(x);
    return t ? (t.innerText || t.textContent || "").trim() : "";
  }).join(" ").trim();
}

test("UNIV-A11Y-lite — inputs have labels; buttons/links have accessible names", async ({ page, baseURL }) => {
  const url = new URL(entry, baseURL || "http://127.0.0.1:8010").toString();
  await page.goto(url, { waitUntil: "domcontentloaded" });

  // 1) Form denetimleri: label/aria-label/aria-labelledby olmalı
  const unlabeledCount = await page.$$eval("input, select, textarea", (els) => {
    function labelledByText(el) {
      const id = el.getAttribute("aria-labelledby");
      if (!id) return "";
      return id.split(/\s+/).map(x => {
        const t = el.ownerDocument.getElementById(x);
        return t ? (t.innerText || t.textContent || "").trim() : "";
      }).join(" ").trim();
    }

    const bad = [];
    for (const el of els) {
      const type = el.getAttribute("type") || "text";
      if (["hidden","submit","button","image","reset","file"].includes(type)) continue;

      const aria = (el.getAttribute("aria-label") || "").trim();
      const by = labelledByText(el);
      let hasExplicit = false;

      // <label for=id>
      const id = el.getAttribute("id");
      if (id) {
        const lab = el.ownerDocument.querySelector(`label[for="${id}"]`);
        if (lab && (lab.innerText || lab.textContent || "").trim().length > 0) hasExplicit = true;
      }
      // <label><input></label>
      let wrapped = false;
      let p = el.parentElement;
      while (p && !wrapped) {
        if (p.tagName.toLowerCase() === "label" && (p.innerText || p.textContent || "").trim().length > 0) wrapped = true;
        p = p.parentElement;
      }
      const ok = hasExplicit || wrapped || aria.length > 0 || by.length > 0;
      if (!ok) bad.push(el.tagName);
    }
    return bad.length;
  });
  expect(unlabeledCount, "Inputs without accessible label").toBe(0);

  // 2) Link & Button: erişilebilir isim (visible text / aria-label / aria-labelledby)
  const unnamedCount = await page.$$eval("a[href], button, [role='button']", (els) => {
    function nameOf(el) {
      const aria = (el.getAttribute("aria-label") || "").trim();
      if (aria) return aria;
      const id = el.getAttribute("aria-labelledby");
      if (id) {
        const txt = id.split(/\s+/).map(x => {
          const t = el.ownerDocument.getElementById(x);
          return t ? (t.innerText || t.textContent || "").trim() : "";
        }).join(" ").trim();
        if (txt) return txt;
      }
      const text = (el.innerText || el.textContent || "").replace(/\s+/g," ").trim();
      return text;
    }
    return els.filter(el => nameOf(el).length === 0).length;
  });
  expect(unnamedCount, "Links/Buttons without accessible name").toBe(0);
});