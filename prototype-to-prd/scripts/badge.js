// prototype-to-prd — callout injector.
// Run via: playwright-cli run-code --filename=<this file>
// Params are read from window.__CALLOUT__, set first via:
//   playwright-cli eval "window.__CALLOUT__={sel:'<css>',n:1,label:'...',color:'#e5484d'}"
// On completion it sets window.__CALLOUT__.found = true|false.
// All injected nodes carry class 'pp-callout' for cleanup:
//   playwright-cli eval "document.querySelectorAll('.pp-callout').forEach(n=>n.remove())"
(() => {
  const p = (window.__CALLOUT__ = window.__CALLOUT__ || {});
  const color = p.color || "#e5484d";
  const el = p.sel ? document.querySelector(p.sel) : null;
  if (!el) {
    p.found = false; // caller treats this as a "miss" → Checkpoint B
    return;
  }
  const r = el.getBoundingClientRect();
  // document coordinates so marks stay correct in full-page captures
  const top = r.top + window.scrollY;
  const left = r.left + window.scrollX;

  // 1) outline overlay (matches the element's box; doesn't disturb layout)
  const outline = document.createElement("div");
  outline.className = "pp-callout";
  Object.assign(outline.style, {
    position: "absolute",
    top: top + "px",
    left: left + "px",
    width: r.width + "px",
    height: r.height + "px",
    border: "3px dashed " + color,
    borderRadius: "6px",
    boxSizing: "border-box",
    pointerEvents: "none",
    zIndex: "2147483646",
  });
  document.body.appendChild(outline);

  // 2) numbered circular badge at the element's top-left
  const badge = document.createElement("div");
  badge.className = "pp-callout";
  badge.textContent = String(p.n != null ? p.n : "?");
  Object.assign(badge.style, {
    position: "absolute",
    top: top - 12 + "px",
    left: left - 12 + "px",
    width: "24px",
    height: "24px",
    background: color,
    color: "#fff",
    font: "700 14px/24px system-ui, sans-serif",
    textAlign: "center",
    borderRadius: "50%",
    boxShadow: "0 1px 3px rgba(0,0,0,.4)",
    pointerEvents: "none",
    zIndex: "2147483647",
  });
  document.body.appendChild(badge);

  // 3) optional label chip next to the badge
  if (p.label) {
    const chip = document.createElement("div");
    chip.className = "pp-callout";
    chip.textContent = (p.n != null ? p.n + "  " : "") + p.label;
    Object.assign(chip.style, {
      position: "absolute",
      top: top - 14 + "px",
      left: left + 16 + "px",
      maxWidth: "320px",
      padding: "2px 8px",
      background: color,
      color: "#fff",
      font: "600 12px/18px system-ui, sans-serif",
      borderRadius: "4px",
      whiteSpace: "nowrap",
      pointerEvents: "none",
      zIndex: "2147483647",
    });
    document.body.appendChild(chip);
  }

  p.found = true;
})();
