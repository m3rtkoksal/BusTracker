(function () {
  const STORES = {
    shuttle: "https://apps.apple.com/tr/app/shuttle-live/id6772752037?l=tr",
    vibe: "https://apps.apple.com/tr/app/vibecheck-dating/id6766612780?l=tr",
    fresh: "https://apps.apple.com/tr/app/freshstart/id6738893033?l=tr",
    hud: "https://apps.apple.com/tr/app/hud-car-speedometer/id6753988482?l=tr",
  };

  const TITLES = {
    shuttle: { tr: "Shuttle Live — Mika Technology", en: "Shuttle Live — Mika Technology" },
    vibe: { tr: "VibeCheck Dating — Mika Technology", en: "VibeCheck Dating — Mika Technology" },
    fresh: { tr: "FreshStart — Mika Technology", en: "FreshStart — Mika Technology" },
    hud: { tr: "HUD Car Speedometer — Mika Technology", en: "HUD Car Speedometer — Mika Technology" },
  };

  const tabs = document.querySelectorAll(".app-tab");
  const panels = document.querySelectorAll(".app-panel");
  const storeLink = document.getElementById("app-store-link");
  const storeHero = document.getElementById("app-store-hero");

  function currentLang() {
    return document.documentElement.lang === "en" ? "en" : "tr";
  }

  function setActive(app) {
    if (!STORES[app]) app = "shuttle";

    document.body.dataset.app = app;

    tabs.forEach((tab) => {
      const on = tab.dataset.app === app;
      tab.classList.toggle("active", on);
      tab.setAttribute("aria-selected", on ? "true" : "false");
    });

    panels.forEach((panel) => {
      const on = panel.dataset.app === app;
      panel.hidden = !on;
      panel.classList.toggle("active", on);
    });

    const url = STORES[app];
    [storeLink, storeHero].forEach((el) => {
      if (!el) return;
      el.href = url;
      el.classList.remove("disabled");
      el.removeAttribute("aria-disabled");
    });

    const title = TITLES[app][currentLang()] || TITLES[app].tr;
    document.title = title;

    if (history.replaceState) {
      const hash = app === "shuttle" ? "" : `#${app}`;
      history.replaceState(null, "", `${location.pathname}${hash}`);
    }

    const tabsEl = document.getElementById("app-tabs");
    if (tabsEl) {
      tabsEl.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => setActive(tab.dataset.app));
  });

  document.body.dataset.app = "shuttle";

  const hash = (location.hash || "").replace("#", "");
  setActive(STORES[hash] ? hash : "shuttle");

  document.addEventListener("langchange", () => {
    const app = document.body.dataset.app || "shuttle";
    const title = TITLES[app][currentLang()] || TITLES[app].tr;
    document.title = title;
  });
})();
