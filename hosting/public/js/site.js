(function () {
  const STORAGE_KEY = "mika.site.lang";

  function preferredLang() {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "tr" || saved === "en") return saved;
    const nav = (navigator.language || "en").toLowerCase();
    return nav.startsWith("tr") ? "tr" : "en";
  }

  function setLang(lang) {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      const value = el.getAttribute(`data-${lang}`);
      if (value != null) el.textContent = value;
    });
    document.querySelectorAll("[data-i18n-html]").forEach((el) => {
      const value =
        el.getAttribute(`data-${lang}-html`) ?? el.getAttribute(`data-${lang}`);
      if (value != null) el.innerHTML = value;
    });
    document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
      const value = el.getAttribute(`data-${lang}-placeholder`);
      if (value != null) el.setAttribute("placeholder", value);
    });
    document.querySelectorAll(".lang-toggle button").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.lang === lang);
    });
    localStorage.setItem(STORAGE_KEY, lang);
    document.dispatchEvent(new CustomEvent("langchange", { detail: { lang } }));
  }

  document.querySelectorAll(".lang-toggle button").forEach((btn) => {
    btn.addEventListener("click", () => setLang(btn.dataset.lang));
  });

  setLang(preferredLang());

  const appStore = document.getElementById("app-store-link");
  if (appStore && (!appStore.href || appStore.getAttribute("href") === "")) {
    appStore.classList.add("disabled");
    appStore.setAttribute("aria-disabled", "true");
  }
})();
