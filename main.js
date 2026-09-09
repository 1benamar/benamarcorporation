(function () {
  "use strict";

  var data = window.__BRAND__ || {};
  var reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---- i18n: language folders live one level below root ---- */
  var BASE = /\/(en|fr)\//.test(location.pathname) ? "../" : "";
  var LANG = document.documentElement.lang || "es";
  var MSG = {
    es: {
      success: "Hemos recibido tu solicitud. Te escribimos en menos de 24h con una propuesta.",
      successNamed: function (name) { return name + ", hemos recibido tu solicitud. Te escribimos en menos de 24h con una propuesta."; },
      error: "No hemos podido enviar tu solicitud. Escríbenos directamente a benamarcorporation@gmail.com."
    },
    en: {
      success: "We've received your request. We'll get back to you within 24h with a real proposal.",
      successNamed: function (name) { return name + ", we've received your request. We'll get back to you within 24h with a real proposal."; },
      error: "We couldn't send your request. Please email us directly at benamarcorporation@gmail.com."
    },
    fr: {
      success: "Nous avons bien reçu votre demande. Nous vous répondons sous 24h avec une proposition réelle.",
      successNamed: function (name) { return name + ", nous avons bien reçu votre demande. Nous vous répondons sous 24h avec une proposition réelle."; },
      error: "Nous n'avons pas pu envoyer votre demande. Écrivez-nous directement à benamarcorporation@gmail.com."
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

    hero.addEventListener("mousemove", function (e) {
      var rect = hero.getBoundingClientRect();
      var px = (e.clientX - rect.left) / rect.width - 0.5;
      var py = (e.clientY - rect.top) / rect.height - 0.5;
      photo.style.transform = "scale(1.08) translate(" + (-px * 22).toFixed(1) + "px, " + (-py * 16).toFixed(1) + "px)";
    }, { passive: true });

    hero.addEventListener("mouseleave", function () {
      photo.style.transform = "scale(1.08) translate(0, 0)";
    });
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

  /* ---- FAQ accordion ---- */
  function initFaqRows() {
    var toggles = $$("[data-faq-toggle]");
    toggles.forEach(function (btn) {
      btn.addEventListener("click", function () {
        var expanded = btn.getAttribute("aria-expanded") === "true";
        toggles.forEach(function (other) {
          if (other !== btn) other.setAttribute("aria-expanded", "false");
        });
        btn.setAttribute("aria-expanded", expanded ? "false" : "true");
      });
    });
  }

  /* ---- Count-up numbers ---- */
  function initCountUp() {
    var els = $$("[data-count-to]");
    if (!els.length) return;
    els.forEach(function (el) {
      var target = parseFloat(el.dataset.countTo);
      var decimals = (el.dataset.countTo.split(".")[1] || "").length;
      var trigger = function () {
        if (window.gsap) {
          var obj = { v: 0 };
          gsap.to(obj, {
            v: target, duration: 1.5, ease: "power2.out",
            onUpdate: function () { el.textContent = obj.v.toFixed(decimals); }
          });
        } else {
          el.textContent = target.toFixed(decimals);
        }
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
    var submitBtn = form.querySelector('[type="submit"]');
    var msg = $("[data-contact-success-msg]");

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (form.classList.contains("is-sending")) return;
      if (!form.reportValidity()) return;

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
            alert(T.error);
          }
        })
        .catch(function () {
          form.classList.remove("is-sending");
          submitBtn.disabled = false;
          alert(T.error);
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
    safe(initNav, "initNav");
    safe(initMobileMenu, "initMobileMenu");
    safe(initSmoothAnchors, "initSmoothAnchors");
    safe(initReveals, "initReveals");
    safe(initFaqRows, "initFaqRows");
    safe(initCountUp, "initCountUp");
    safe(initContactForm, "initContactForm");
    safe(initFooterYear, "initFooterYear");

    if (window.gsap && window.ScrollTrigger) {
      try { gsap.registerPlugin(ScrollTrigger); } catch (e) {}
    }

    document.documentElement.classList.add("is-ready");
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
