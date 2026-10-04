// Turns the "installer delivered by the author" text into a download link
// when config.js names where the installer is. Without JavaScript, or with
// an empty address, the page keeps the plain text and shows no dead link.
(function () {
  var config = window.SHOWROOM || {};
  var url = typeof config.apkUrl === "string" ? config.apkUrl.trim() : "";
  if (url.indexOf("https://") !== 0) return;

  var slots = document.querySelectorAll("[data-apk]");
  for (var i = 0; i < slots.length; i += 1) {
    var link = document.createElement("a");
    link.href = url;
    link.className = slots[i].getAttribute("data-apk-class") || "";
    link.textContent = slots[i].getAttribute("data-apk-label") || "Descargar el instalador";
    link.rel = "noopener";
    slots[i].textContent = "";
    slots[i].appendChild(link);
  }
})();
