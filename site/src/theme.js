import { $ } from "./dom.js";

// Three-state theme: light / dark / system. The initial decision happens in
// an inline <head> script to avoid a paint flash; this module owns the
// cycle button and keeps the icon + .dark class in sync.

const KEY = "theme";

// Heroicons outline at 24x24. Inlined so the icon inherits text colour and
// renders identically across platforms (Unicode sun/moon glyphs vary
// wildly between macOS, Windows, and Linux).
const SVG_ATTRS = 'xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4"';
const ICONS = {
  light: `<svg ${SVG_ATTRS}><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"/></svg>`,
  dark:  `<svg ${SVG_ATTRS}><path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"/></svg>`,
  system:`<svg ${SVG_ATTRS}><path stroke-linecap="round" stroke-linejoin="round" d="M9 17.25v1.007a3 3 0 0 1-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0 1 15 18.257V17.25m6-12V15a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 15V5.25m18 0A2.25 2.25 0 0 0 18.75 3H5.25A2.25 2.25 0 0 0 3 5.25m18 0V12a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 12V5.25"/></svg>`,
};
const TITLES = {
  light: "Light theme — click for dark",
  dark: "Dark theme — click for system",
  system: "System theme — click for light",
};

function currentChoice() {
  try { return localStorage.getItem(KEY) || "system"; } catch (_) { return "system"; }
}

function prefersDark() {
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
}

function apply(choice) {
  const dark = choice === "dark" || (choice === "system" && prefersDark());
  document.documentElement.classList.toggle("dark", dark);
  const icon = $("#theme-icon");
  const btn = $("#theme-toggle");
  if (icon) icon.innerHTML = ICONS[choice];
  if (btn) btn.title = TITLES[choice];
}

function setChoice(choice) {
  try {
    if (choice === "system") localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, choice);
  } catch (_) {}
  apply(choice);
}

export function initTheme() {
  apply(currentChoice());
  const btn = $("#theme-toggle");
  if (btn) {
    btn.addEventListener("click", () => {
      const next = { light: "dark", dark: "system", system: "light" }[currentChoice()];
      setChoice(next);
    });
  }
  // Track the OS preference while the choice is "system".
  if (window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      if (currentChoice() === "system") apply("system");
    });
  }
}
