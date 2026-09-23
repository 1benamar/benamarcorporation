(function () {
  "use strict";

  var data = window.__BRAND__ || {};
  var reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---- i18n: language folders live one level below root ---- */
  var BASE = /\/(en|fr)\//.test(location.pathname) ? "../" : "";
  var LANG = document.documentElement.lang || "es";
  var MSG = {
    es: {
      success: "Hemos recibido su solicitud. Le escribimos en menos de 24 horas con una propuesta.",
      successNamed: function (name) { return name + ", hemos recibido su solicitud. Le escribimos en menos de 24 horas con una propuesta."; },
      error: "No hemos podido enviar su solicitud. Escríbanos directamente a contact@benamar.es."
    },
    en: {
      success: "We have received your request. We will reply within 24 hours with a concrete proposal.",
      successNamed: function (name) { return name + ", we have received your request. We will reply within 24 hours with a concrete proposal."; },
      error: "We could not send your request. Please write to us directly at contact@benamar.es."
    },
    fr: {
      success: "Nous avons bien reçu votre demande. Nous vous répondons sous 24 heures avec une proposition concrète.",
      successNamed: function (name) { return name + ", nous avons bien reçu votre demande. Nous vous répondons sous 24 heures avec une proposition concrète."; },
      error: "Nous n'avons pas pu envoyer votre demande. Veuillez nous écrire directement à contact@benamar.es."
    }
  };
  var T = MSG[LANG] || MSG.es;

  var $ = function (sel, scope) { return (scope || document).querySelector(sel); };
  var $$ = function (sel, scope) { return Array.prototype.slice.call((scope || document).querySelectorAll(sel)); };

  function safe(fn, name) {
    try { fn(); } catch (e) { console.warn("[" + name + "]", e); }
  }

  /* ---- Hero photo mouse parallax ---- */
  function initHeroParallax() {
    var hero = $("[data-hero]");
    var photo = $("[data-hero-photo]");
    if (!hero || !photo || reduced) return;
    if (!matchMedia("(hover: hover) and (pointer: fine)").matches) return;

    // La medida del encabezado se toma una vez y se invalida al hacer scroll
    // o cambiar el tamaño, en lugar de leerla en cada movimiento del ratón.
    // Los movimientos se agrupan: como mucho un cambio por fotograma.
    var rect = null, px = 0, py = 0, raf = null;
    function apply() {
      photo.style.transform = "scale(1.08) translate3d(" + (-px * 22).toFixed(1) + "px, " + (-py * 16).toFixed(1) + "px, 0)";
      raf = null;
    }
    function queue() { if (!raf) raf = requestAnimationFrame(apply); }
    function forget() { rect = null; }
    window.addEventListener("scroll", forget, { passive: true });
    window.addEventListener("resize", forget, { passive: true });

    hero.addEventListener("mousemove", function (e) {
      if (!rect) rect = hero.getBoundingClientRect();
      px = (e.clientX - rect.left) / rect.width - 0.5;
      py = (e.clientY - rect.top) / rect.height - 0.5;
      queue();
    }, { passive: true });

    hero.addEventListener("mouseleave", function () {
      px = 0; py = 0;
      queue();
    });
  }

  /* ---- Scroll progress bar ---- */
  function initScrollProgress() {
    var bar = $("[data-scroll-progress]");
    if (!bar) return;
    var raf = null;
    function update() {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      var pct = max > 0 ? window.scrollY / max : 0;
      bar.style.transform = "scaleX(" + Math.min(1, Math.max(0, pct)).toFixed(4) + ")";
      raf = null;
    }
    window.addEventListener("scroll", function () {
      if (!raf) raf = requestAnimationFrame(update);
    }, { passive: true });
    update();
  }

  /* ---- Sticky nav ---- */
  function initNav() {
    var nav = $("[data-nav]");
    if (!nav) return;
    var onScroll = function () {
      if (window.scrollY > 24) nav.classList.add("is-scrolled");
      else nav.classList.remove("is-scrolled");
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ---- Mobile menu ---- */
  function initMobileMenu() {
    var burger = $("[data-nav-burger]");
    var menu = $("[data-nav-mobile]");
    if (!burger || !menu) return;
    var links = $$("[data-nav-mobile-link]", menu);

    function close() {
      burger.setAttribute("aria-expanded", "false");
      menu.classList.remove("is-open");
      menu.setAttribute("aria-hidden", "true");
      document.body.style.overflow = "";
    }
    function open() {
      burger.setAttribute("aria-expanded", "true");
      menu.classList.add("is-open");
      menu.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
    }
    burger.addEventListener("click", function () {
      var isOpen = burger.getAttribute("aria-expanded") === "true";
      if (isOpen) close(); else open();
    });
    links.forEach(function (a) { a.addEventListener("click", close); });
  }

  /* ---- Smooth anchors (native scroll — see gotcha B.1.4) ---- */
  function initSmoothAnchors() {
    document.addEventListener("click", function (e) {
      var a = e.target.closest ? e.target.closest('a[href^="#"]') : null;
      if (!a) return;
      var id = a.getAttribute("href");
      if (!id || id === "#") return;
      var el = document.querySelector(id);
      if (!el) return;
      e.preventDefault();
      var navOffset = 72;
      window.scrollTo({
        top: el.getBoundingClientRect().top + window.scrollY - navOffset,
        behavior: reduced ? "auto" : "smooth"
      });
    });
  }

  /* ---- Reveal on scroll (fade + fade/scale variants) ---- */
  /* ---- Ancla al llegar desde otra página ---- */
  function initHashOnLoad() {
    if (!window.location.hash) return;
    var el;
    try { el = document.querySelector(window.location.hash); } catch (err) { return; }
    if (!el) return;

    // El navegador salta al ancla antes de que carguen las tipografías, y
    // al cambiar la métrica del texto la sección se mueve. Se recoloca
    // cuando las fuentes están listas, y se deja de hacer en cuanto el
    // visitante toma el control del desplazamiento.
    var manda = false;
    function suelta() { manda = true; }
    window.addEventListener("wheel", suelta, { passive: true, once: true });
    window.addEventListener("touchstart", suelta, { passive: true, once: true });
    window.addEventListener("keydown", suelta, { once: true });

    function go() {
      if (manda) return;
      window.scrollTo({
        top: el.getBoundingClientRect().top + window.scrollY - 72,
        behavior: "auto"
      });
    }

    window.addEventListener("load", function () {
      go();
      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(go).catch(function () {});
      }
      setTimeout(go, 400);
    });
  }

  function initReveals() {
    var els = $$("[data-reveal], [data-reveal-scale]");
    if (!els.length) return;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-revealed");
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.01, rootMargin: "0px 0px -2% 0px" });
    els.forEach(function (el) { io.observe(el); });

    setTimeout(function () {
      $$("[data-reveal]:not(.is-revealed), [data-reveal-scale]:not(.is-revealed)").forEach(function (el) {
        if (el.getBoundingClientRect().top < window.innerHeight) {
          el.classList.add("is-revealed");
        }
      });
    }, 6000);
  }

  /* ---- Count-up numbers ---- */
  function initCountUp() {
    var els = $$("[data-count-to]");
    if (!els.length) return;
    els.forEach(function (el) {
      var target = parseFloat(el.dataset.countTo);
      var decimals = (el.dataset.countTo.split(".")[1] || "").length;
      var trigger = function () {
        var start = null, duration = 1500;
        function frame(now) {
          if (start === null) start = now;
          var p = Math.min(1, (now - start) / duration);
          var eased = 1 - (1 - p) * (1 - p);
          el.textContent = (target * eased).toFixed(decimals);
          if (p < 1) requestAnimationFrame(frame);
        }
        requestAnimationFrame(frame);
      };
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) { trigger(); io.unobserve(entry.target); }
        });
      }, { threshold: 0.4 });
      io.observe(el);
    });
  }

  /* ---- Contact form (real submit via contact.php) ---- */
  function initContactForm() {
    var form = $("[data-contact-form]");
    var success = $("[data-contact-success]");
    if (!form || !success) return;
    var errorBox = $("[data-contact-error]");

    // El aviso del navegador se cierra y no deja rastro. Un panel en la
    // página mantiene a la vista las otras formas de contacto, para que
    // una solicitud no se pierda porque el correo del servidor falle.
    function mostrarFallo() {
      if (!errorBox) { alert(T.error); return; }
      errorBox.hidden = false;
      errorBox.setAttribute("role", "alert");
      errorBox.scrollIntoView({ block: "center", behavior: reduced ? "auto" : "smooth" });
    }
    function ocultarFallo() {
      if (errorBox) errorBox.hidden = true;
    }
    var submitBtn = form.querySelector('[type="submit"]');
    var msg = $("[data-contact-success-msg]");

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (form.classList.contains("is-sending")) return;
      if (!form.reportValidity()) return;

      ocultarFallo();
      form.classList.add("is-sending");
      submitBtn.disabled = true;

      var firstName = (form.elements.name.value.trim().split(/\s+/)[0]) || "";

      fetch(BASE + "contact.php", {
        method: "POST",
        body: new FormData(form)
      })
        .then(function (res) { return res.json(); })
        .then(function (data) {
          form.classList.remove("is-sending");
          submitBtn.disabled = false;

          if (data && data.success) {
            if (msg) msg.textContent = firstName ? T.successNamed(firstName) : T.success;
            form.classList.add("is-sent");
            success.setAttribute("aria-hidden", "false");
            success.classList.add("is-visible");
          } else {
            mostrarFallo();
          }
        })
        .catch(function () {
          form.classList.remove("is-sending");
          submitBtn.disabled = false;
          mostrarFallo();
        });
    });
  }

  /* ---- Footer year ---- */
  function initFooterYear() {
    var el = $("[data-year]");
    if (el) el.textContent = new Date().getFullYear();
  }

  function boot() {
    safe(initHeroParallax, "initHeroParallax");
    safe(initScrollProgress, "initScrollProgress");
    safe(initNav, "initNav");
    safe(initMobileMenu, "initMobileMenu");
    safe(initSmoothAnchors, "initSmoothAnchors");
    safe(initHashOnLoad, "initHashOnLoad");
    safe(initReveals, "initReveals");
    safe(initCountUp, "initCountUp");
    safe(initContactForm, "initContactForm");
    safe(initFooterYear, "initFooterYear");

    document.documentElement.classList.add("is-ready");
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
