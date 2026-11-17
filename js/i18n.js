// Idiomas: el texto del HTML está en el idioma base (data-base); los demás, en window.I18N_XX (js/lang.js).
// data-i18n="clave" cambia el contenido; data-i18n-attr="aria-label:clave;alt:clave2" cambia atributos.
// Guarda la elección (?lang=xx, localStorage <site>-lang) y avisa con el evento "langchange".
// I18N.t({es, en, fr, ro}) devuelve el texto del idioma actual (o el del idioma base).
// Mismo motor que nou-cafe-mar; aquí el navegador en árabe abre en francés (Marruecos) y el catalán, en catalán.
(() => {
  const me = document.currentScript;
  const site = me?.dataset.site || 'web';
  const BASE = me?.dataset.base || document.documentElement.lang || 'es';
  const LANGS = (me?.dataset.langs || BASE).split(',').map((s) => s.trim());
  const KEY = site + '-lang';
  const D = {};
  LANGS.forEach((l) => { if (l !== BASE) D[l] = window['I18N_' + l.toUpperCase()] || {}; });
  const orig = new Map();
  let origTitle = null;
  const store = (k, v) => { try { localStorage.setItem(k, v); } catch (_) { /* sin almacenamiento */ } };
  const load = (k) => { try { return localStorage.getItem(k); } catch (_) { return null; } };
  const pick = (lang, k, fallback) => (D[lang] && D[lang][k] != null ? D[lang][k] : fallback);

  function apply(lang) {
    if (!LANGS.includes(lang)) lang = BASE;
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      if (!orig.has(el)) orig.set(el, el.innerHTML);
      el.innerHTML = pick(lang, el.dataset.i18n, orig.get(el));
    });
    document.querySelectorAll('[data-i18n-attr]').forEach((el) => {
      el.dataset.i18nAttr.split(';').forEach((pair) => {
        const [attr, k] = pair.split(':').map((s) => s.trim());
        const ok = 'i18nOrig' + attr.replace(/(^|-)./g, (m) => m.slice(-1).toUpperCase());
        if (el.dataset[ok] == null) el.dataset[ok] = el.getAttribute(attr) || '';
        el.setAttribute(attr, pick(lang, k, el.dataset[ok]));
      });
    });
    document.documentElement.lang = lang;
    if (origTitle == null) origTitle = document.title;
    document.title = pick(lang, document.documentElement.dataset.titleKey || '_title', origTitle);
    const desc = document.querySelector('meta[name="description"]');
    if (desc) { if (!desc.dataset.orig) desc.dataset.orig = desc.content; desc.content = pick(lang, document.documentElement.dataset.descKey || '_desc', desc.dataset.orig); }
    document.querySelectorAll('[data-lang]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
    store(KEY, lang);
    document.dispatchEvent(new CustomEvent('langchange', { detail: { lang } }));
  }

  const nav = (navigator.language || BASE).slice(0, 2).toLowerCase();
  const alias = { gl: 'es', eu: 'es', ar: 'fr', zgh: 'fr', mo: 'ro' };
  const fromNav = LANGS.includes(nav) ? nav : (alias[nav] && LANGS.includes(alias[nav]) ? alias[nav] : (LANGS.includes('en') ? 'en' : BASE));
  const start = new URLSearchParams(location.search).get('lang') || load(KEY) || fromNav;
  const cur = () => document.documentElement.lang;
  window.I18N = { set: apply, get: cur, base: BASE, t: (m) => (m && (m[cur()] ?? m[BASE])) || '' };
  document.addEventListener('click', (e) => { const b = e.target.closest('[data-lang]'); if (b) { e.preventDefault(); apply(b.dataset.lang); } });
  const go = () => apply(start);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', go); else go();
})();
