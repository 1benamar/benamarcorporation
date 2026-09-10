(function () {
  "use strict";
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var header = document.querySelector("header");
  if (header) {
    var onScroll = function () {
      header.classList.toggle("is-scrolled", window.scrollY > 8);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  if (reduceMotion) return;

  var revealEls = document.querySelectorAll(
    ".section-head, .card, .gallery-tile, .plan-item, .trust-item, .faq-item, " +
    ".split-media, .split > div:first-child, .brochure-band, .chip-list, " +
    ".contact-grid > div, .stats-bar > div"
  );

  var groups = new Map();
  revealEls.forEach(function (el) {
    el.classList.add("reveal");
    var parent = el.parentElement;
    var step = groups.get(parent) || 0;
    groups.set(parent, step + 1);
    el.style.transitionDelay = Math.min(step * 70, 280) + "ms";
  });

  var io = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-revealed");
        io.unobserve(entry.target);
        var counter = entry.target.querySelector(".stat-value");
        var self = entry.target.classList.contains("stat-value") ? entry.target : null;
        countUp(counter || self);
      });
    },
    { threshold: 0.15, rootMargin: "0px 0px -40px 0px" }
  );
  revealEls.forEach(function (el) { io.observe(el); });

  function countUp(el) {
    if (!el || el.dataset.counted) return;
    var original = el.textContent.trim();
    var digits = original.replace(/[^0-9]/g, "");
    if (!digits) return;
    el.dataset.counted = "1";
    var target = parseInt(digits, 10);
    var duration = 900;
    var start = null;
    function step(ts) {
      if (!start) start = ts;
      var progress = Math.min((ts - start) / duration, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      el.textContent = Math.floor(eased * target).toLocaleString("es-ES");
      if (progress < 1) requestAnimationFrame(step);
      else el.textContent = original;
    }
    requestAnimationFrame(step);
  }
})();
