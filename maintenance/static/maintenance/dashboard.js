// Basit UI yardımcıları
const MaintenanceUI = {
  toast(msg) {
    const n = document.createElement("div");
    n.className = "toast";
    n.textContent = msg;
    Object.assign(n.style, {
      position: "fixed", bottom: "18px", right: "18px",
      background: "#0f2a4d", color: "#fff", padding: "10px 14px",
      borderRadius: "12px", boxShadow: "0 10px 30px rgba(0,0,0,.12)", zIndex: 2000
    });
    document.body.appendChild(n);
    setTimeout(()=>n.remove(), 2000);
  }
};

document.addEventListener("DOMContentLoaded", () => {
  // Ticker hız kontrolü (CSS animasyon süresi)
  document.querySelectorAll(".ticker").forEach(t => {
    const speed = Number(t.dataset.speed || 12);
    t.querySelectorAll(".tick").forEach(item => {
      item.style.animationDuration = `${speed}s`;
    });
  });
  console.debug("Maintenance dashboard ready.");
});
