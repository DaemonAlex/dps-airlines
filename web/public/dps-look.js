// DelPerroSands bubble look for screens whose colours are built into their code (no style file to change).
// Watches the page and recolours dark panels as they appear: dark solid backgrounds -> burnt orange,
// faint borders -> white. Skips full-screen layers, pictures, video, canvases and the map.
(() => {
  const FILL = 'rgba(184, 83, 42, 0.86)', LINE = 'rgba(255, 255, 255, 0.9)';
  const SKIP = /^(IMG|VIDEO|CANVAS|SVG|PATH|IFRAME|SCRIPT|STYLE|LINK|HTML|BODY)$/;
  const parse = (c) => { const m = c && c.match(/rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/); return m ? [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]] : null; };
  const light = ([r, g, b]) => (Math.max(r, g, b) + Math.min(r, g, b)) / 510;
  function fix(el) {
    if (!el || el.nodeType !== 1 || SKIP.test(el.tagName) || el.dataset.dpsLook) return;
    const s = getComputedStyle(el), bg = parse(s.backgroundColor);
    if (bg && bg[3] > 0.5 && light(bg) < 0.22 && s.backgroundImage === 'none') {
      const r = el.getBoundingClientRect();
      if (!(r.width >= innerWidth * 0.9 && r.height >= innerHeight * 0.9)) {
        const inner = el.parentElement && el.parentElement.closest('[data-dps-fill]');   // orange never stacks on orange
        el.style.setProperty('background-color', inner ? 'rgba(255, 255, 255, 0.12)' : FILL, 'important');
        if (!inner) el.dataset.dpsFill = '1';
        const bc = parse(s.borderTopColor);
        if (parseFloat(s.borderTopWidth) > 0 && bc && light(bc) < 0.5) el.style.setProperty('border-color', LINE, 'important');
      }
    }
    if (s.backdropFilter && s.backdropFilter !== 'none') el.style.setProperty('backdrop-filter', 'none', 'important');
    el.dataset.dpsLook = '1';
  }
  const sweep = (root) => { fix(root); if (root.querySelectorAll) root.querySelectorAll('*').forEach(fix); };
  const start = () => {
    const f = document.createElement('link'); f.rel = 'stylesheet';
    f.href = 'https://fonts.googleapis.com/css2?family=Bangers&family=Comic+Neue:ital,wght@0,400;0,700;1,700&display=swap';
    document.head.appendChild(f);
    const st = document.createElement('style');
    st.textContent = 'body{font-family:"Comic Neue","Comic Sans MS",Roboto,sans-serif;text-shadow:0 1px 2px rgba(0,0,0,.45)}';
    document.head.appendChild(st);
    sweep(document.body);
    new MutationObserver((ms) => { for (const m of ms) { if (m.type === 'childList') m.addedNodes.forEach((n) => n.nodeType === 1 && sweep(n));
      else if (m.target.nodeType === 1) { delete m.target.dataset.dpsLook; fix(m.target); } } })
      .observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
  };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
})();
