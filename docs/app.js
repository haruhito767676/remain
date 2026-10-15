// The hero: "Just remain awake." unfolds as you scroll. "ai" lights up and becomes "AI", the words around it fall
// away, the icon appears, and what is left is the name: remAIn. The page is complete without this script
// (the CSS already shows the finished state); the script only plays the animation.
(() => {
  const hero = document.querySelector('[data-hero]');
  if (!hero) return;
  const clamp01 = (v) => Math.max(0, Math.min(1, v));
  const ease = (x) => 0.5 - 0.5 * Math.cos(Math.PI * clamp01(x));
  const easeOut = (x) => 1 - Math.pow(1 - clamp01(x), 3);
  const prog = (p, a, b) => clamp01((p - a) / (b - a));

  const sides = [...hero.querySelectorAll('[data-side]')];
  const wrap = hero.querySelector('.aiwrap');
  const base = wrap.querySelector('.lo');
  const glow = wrap.querySelector('.ai');
  const widths = [];
  const measure = () => {
    sides.forEach((el, i) => { el.style.maxWidth = 'none'; el.style.opacity = '1'; widths[i] = el.getBoundingClientRect().width; });
  };

  function render(p) {
    const lit = ease(prog(p, 0.12, 0.28));
    const pop = prog(p, 0.32, 0.44);
    const upper = pop > 0.5;
    const collapse = ease(prog(p, 0.5, 0.7));
    const icon = easeOut(prog(p, 0.58, 0.74));
    const rest = easeOut(prog(p, 0.78, 0.94));
    hero.style.setProperty('--icon', icon.toFixed(3));
    hero.style.setProperty('--rest', rest.toFixed(3));
    hero.style.setProperty('--hint', (1 - prog(p, 0.02, 0.1)).toFixed(3));
    sides.forEach((el, i) => {
      el.style.maxWidth = (widths[i] * (1 - collapse)).toFixed(1) + 'px';
      el.style.opacity = (1 - collapse).toFixed(3);
    });
    const text = upper ? 'AI' : 'ai';
    base.textContent = text; glow.textContent = text;
    base.style.opacity = (1 - lit).toFixed(3);
    glow.style.opacity = lit.toFixed(3);
    glow.style.filter = `drop-shadow(0 0 ${(lit * 26).toFixed(0)}px rgba(143, 176, 255, 0.65))`;
    wrap.style.transform = `scale(${(1 + 0.16 * Math.sin(Math.PI * pop)).toFixed(3)})`;
  }

  const small = matchMedia('(max-width: 720px)');
  const still = matchMedia('(prefers-reduced-motion: reduce)');
  let raf = 0, playing = 0;

  function pinned() {
    const range = hero.offsetHeight - hero.querySelector('.stick').offsetHeight;
    return clamp01(-hero.getBoundingClientRect().top / Math.max(1, range));
  }
  function onScroll() { if (!raf) raf = requestAnimationFrame(() => { raf = 0; render(pinned()); }); }
  // A phone does not pin the hero: the animation plays once on its own.
  function autoplay() {
    const start = performance.now(), length = 4200;
    const step = (now) => {
      const p = clamp01((now - start) / length);
      render(p);
      if (p < 1) playing = requestAnimationFrame(step);
    };
    cancelAnimationFrame(playing); render(0); playing = requestAnimationFrame(step);
  }

  function setup() {
    removeEventListener('scroll', onScroll);
    cancelAnimationFrame(playing);
    measure();
    if (still.matches) { render(1); return; }
    if (small.matches) { autoplay(); return; }
    addEventListener('scroll', onScroll, { passive: true });
    render(pinned());
  }
  document.fonts.ready.then(setup);
  addEventListener('resize', () => { measure(); if (!small.matches && !still.matches) render(pinned()); });
  small.addEventListener('change', setup);
})();

// FAQ: the answers open and close smoothly (the page works the same without this).
(() => {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  document.querySelectorAll('.faq details').forEach((d) => {
    const summary = d.querySelector('summary');
    let anim = null;
    summary.addEventListener('click', (e) => {
      e.preventDefault();
      if (anim) anim.cancel();
      const cs = getComputedStyle(d);
      const collapsed = summary.offsetHeight + parseFloat(cs.paddingTop) + parseFloat(cs.paddingBottom) + parseFloat(cs.borderTopWidth) + parseFloat(cs.borderBottomWidth);
      const from = d.offsetHeight;
      d.style.overflow = 'hidden';
      const opening = !d.open;
      if (opening) d.open = true;
      const to = opening ? d.offsetHeight : collapsed;
      anim = d.animate({ height: [from + 'px', to + 'px'] }, { duration: 260, easing: 'cubic-bezier(.3,.7,.2,1)' });
      const done = () => { anim = null; d.style.overflow = ''; if (!opening) d.open = false; };
      anim.onfinish = done; anim.oncancel = () => { d.style.overflow = ''; };
    });
  });
})();
