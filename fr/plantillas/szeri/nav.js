(function () {
  "use strict";
  var burger = document.querySelector("[data-nav-burger]");
  var mobile = document.querySelector("[data-nav-mobile]");
  if (!burger || !mobile) return;

  function close() {
    mobile.classList.remove("is-open");
    burger.setAttribute("aria-expanded", "false");
    mobile.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
  }
  function open() {
    mobile.classList.add("is-open");
    burger.setAttribute("aria-expanded", "true");
    mobile.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
  }
  burger.addEventListener("click", function () {
    var isOpen = burger.getAttribute("aria-expanded") === "true";
    if (isOpen) close(); else open();
  });
  mobile.querySelectorAll("a").forEach(function (a) {
    a.addEventListener("click", close);
  });
})();
