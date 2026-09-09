(function () {
  "use strict";

  var BASE = /\/(en|fr)\//.test(location.pathname) ? "../" : "";
  var LANG = document.documentElement.lang || "es";
  var DICT = {
    es: {
      unknownAuthor: "Autor desconocido",
      noTitle: "Sin título",
      viewOriginal: "Ver original ↗",
      noCredits: "No hay imágenes con licencia registradas.",
      loadError: "No se ha podido cargar la lista de créditos (esto puede pasar al abrir el archivo directamente sin servidor). Consulta <code>assets/credits.json</code>."
    },
    en: {
      unknownAuthor: "Unknown author",
      noTitle: "Untitled",
      viewOriginal: "View original ↗",
      noCredits: "No licensed images registered.",
      loadError: "The credits list couldn't be loaded (this can happen when opening the file directly without a server). Check <code>assets/credits.json</code>."
    },
    fr: {
      unknownAuthor: "Auteur inconnu",
      noTitle: "Sans titre",
      viewOriginal: "Voir l'original ↗",
      noCredits: "Aucune image sous licence enregistrée.",
      loadError: "Impossible de charger la liste des crédits (cela peut arriver en ouvrant le fichier directement sans serveur). Consultez <code>assets/credits.json</code>."
    }
  };
  var T = DICT[LANG] || DICT.es;

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
      list.innerHTML = "<li>" + T.noCredits + "</li>";
      return;
    }
    list.innerHTML = entries.map(function (c) {
      var creatorHtml = c.creator_url
        ? '<a href="' + esc(c.creator_url) + '" target="_blank" rel="noopener">' + esc(c.creator || T.unknownAuthor) + "</a>"
        : esc(c.creator || T.unknownAuthor);
      return (
        "<li>" +
        "<strong>" + esc(c.title || T.noTitle) + "</strong> — " + creatorHtml +
        " (" + esc(c.source || "") + ") · " +
        '<a href="' + esc(c.license_url) + '" target="_blank" rel="noopener">' +
        esc((c.license || "").toUpperCase()) + " " + esc(c.license_version || "") +
        "</a> · " +
        '<a href="' + esc(c.foreign_landing_url) + '" target="_blank" rel="noopener">' + T.viewOriginal + "</a>" +
        "</li>"
      );
    }).join("");
  }

  function boot() {
    fetch(BASE + "assets/credits.json")
      .then(function (r) { return r.json(); })
      .then(render)
      .catch(function (e) {
        console.warn("[credits]", e);
        var list = document.querySelector("[data-credits]");
        if (list) list.innerHTML = "<li>" + T.loadError + "</li>";
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
