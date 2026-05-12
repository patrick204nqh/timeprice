import { $ } from "./dom.js";

// Three-state theme: light / dark / system. The initial decision happens in
// an inline <head> script to avoid a paint flash; this module owns the
// cycle button and keeps the icon + .dark class in sync.

const KEY = "theme";
const ICONS = { light: "☀︎", dark: "☾", system: "◐" };
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
  if (icon) icon.textContent = ICONS[choice];
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
