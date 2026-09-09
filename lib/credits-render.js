(function () {
  "use strict";

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function render(credits) {
    var list = document.querySelector("[data-credits]");
    if (!list) return;
    var entries = Object.keys(credits).map(function (id) { return credits[id]; });
    if (!entries.length) {
      list.innerHTML = "<li>No hay imágenes con licencia registradas.</li>";
      return;
    }
    list.innerHTML = entries.map(function (c) {
      var creatorHtml = c.creator_url
        ? '<a href="' + esc(c.creator_url) + '" target="_blank" rel="noopener">' + esc(c.creator || "Autor desconocido") + "</a>"
        : esc(c.creator || "Autor desconocido");
      return (
        "<li>" +
        "<strong>" + esc(c.title || "Sin título") + "</strong> — " + creatorHtml +
        " (" + esc(c.source || "") + ") · " +
        '<a href="' + esc(c.license_url) + '" target="_blank" rel="noopener">' +
        esc((c.license || "").toUpperCase()) + " " + esc(c.license_version || "") +
        "</a> · " +
        '<a href="' + esc(c.foreign_landing_url) + '" target="_blank" rel="noopener">Ver original ↗</a>' +
        "</li>"
      );
    }).join("");
  }

  function boot() {
    fetch("assets/credits.json")
      .then(function (r) { return r.json(); })
      .then(render)
      .catch(function (e) {
        console.warn("[credits]", e);
        var list = document.querySelector("[data-credits]");
        if (list) list.innerHTML = "<li>No se ha podido cargar la lista de créditos (esto puede pasar al abrir el archivo directamente sin servidor). Consulta <code>assets/credits.json</code>.</li>";
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
