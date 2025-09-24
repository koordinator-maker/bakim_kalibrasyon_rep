// REV: 1.0 | 2025-09-24 | Hash: daab89bd | Parça: 1/1
// REV: 1.0 | 2025-09-24 | Hash: 4052105c | Parça: 1/1
// Basit UI yardımcıları
const MaintenanceUI = {
  toast(msg) {
    const n = document.createElement("div");
    n.className = "toast";
    n.textContent = msg;
    Object.assign(n.style, {
      position: "fixed", bottom: "18px", right: "18px",
      background: "#0f2a4d", color: "#fff", padding: "10px 14px",
      borderRadius: "12px", boxShadow: "0 10px 30px rgba(0,0,0,0.12)", zIndex: 2000
    });
    document.body.appendChild(n);
    setTimeout(()=>n.remove(), 2000);
  }
};

function applyTheme(theme){
  const html = document.documentElement;
  html.dataset.theme = theme;
  html.classList.toggle("dark", theme === "dark");
  html.classList.toggle("light", theme !== "dark");
}

function initTheme(){
  try{
    const saved = localStorage.getItem("bk-theme");
    const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    const theme = saved || (prefersDark ? "dark" : "light");
    applyTheme(theme);
  }catch(e){ applyTheme("light"); }
}

function toggleTheme(){
  const cur = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  applyTheme(cur);
  try{ localStorage.setItem("bk-theme", cur); }catch(e){}
}

document.addEventListener("DOMContentLoaded", () => {
  // Tema
  initTheme();
  const btn = document.getElementById("themeToggle");
  if(btn){ btn.addEventListener("click", toggleTheme); }

  // Ticker hız kontrolü (CSS animasyon süresi)
  document.querySelectorAll(".ticker").forEach(t => {
    const speed = Number(t.dataset.speed || 12);
    t.querySelectorAll(".tick").forEach(item => {
      item.style.animationDuration = `${speed}s`;
    });
  });

  // Ticker item'ları tıklanabilir (eğer içinde anchor varsa)
  document.querySelectorAll(".tick[data-href], .tick a").forEach(item => {
    const href = item.getAttribute("data-href");
    if(href){
      item.style.cursor = "pointer";
      item.addEventListener("click", () => { window.location.href = href; });
    }
  });

  console.debug("Maintenance dashboard ready.");
});
