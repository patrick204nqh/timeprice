import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm, applyRangeForCountry } from "./form.js";
import { renderSnippet } from "./snippet.js";
import { renderHero } from "./result.js";
import { writeUrl } from "./url.js";
import { calculate } from "./calculate.js";

export function bindTabs() {
  for (const t of document.querySelectorAll(".tab")) {
    t.addEventListener("click", (e) => {
      if (t.getAttribute("aria-disabled") === "true") { e.preventDefault(); return; }
      const name = t.dataset.tab;
      state.tab = name;
      document.querySelectorAll(".tab").forEach(el => {
        const sel = el.dataset.tab === name;
        el.setAttribute("aria-selected", sel);
        el.classList.toggle("bg-stone-200", sel);
        el.classList.toggle("dark:bg-stone-800", sel);
        if (el.getAttribute("aria-disabled") !== "true") {
          el.classList.toggle("text-stone-500", !sel);
        }
      });
      document.querySelectorAll(".panel").forEach(p => {
        p.classList.toggle("hidden", p.dataset.panel !== name);
      });
      writeUrl();
    });
  }
  // initial selected style
  document.querySelector('.tab[data-tab="inflation"]').classList.add("bg-stone-200", "dark:bg-stone-800");
}

export function bindSnippetToggle() {
  for (const b of document.querySelectorAll(".snip-toggle")) {
    b.addEventListener("click", () => {
      state.snippetMode = b.dataset.snippet;
      document.querySelectorAll(".snip-toggle").forEach(el => {
        const sel = el.dataset.snippet === state.snippetMode;
        el.setAttribute("aria-selected", sel);
        el.classList.toggle("bg-stone-200", sel);
        el.classList.toggle("dark:bg-stone-800", sel);
        el.classList.toggle("text-stone-500", !sel);
      });
      renderSnippet();
    });
  }
  document.querySelector('.snip-toggle[data-snippet="ruby"]').classList.add("bg-stone-200", "dark:bg-stone-800");
}

export function bindCopyButtons() {
  document.body.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-copy], #snip-copy");
    if (!btn) return;
    const text = btn.dataset.copy || $("#snippet").textContent;
    try { await navigator.clipboard.writeText(text); } catch {}
    if (!btn.dataset.origText) btn.dataset.origText = btn.textContent;
    btn.textContent = "copied";
    setTimeout(() => { btn.textContent = btn.dataset.origText; }, 1200);
  });
}

let calcTimer = null;
function scheduleCalc() {
  clearTimeout(calcTimer);
  calcTimer = setTimeout(calculate, 200);
}

export function bindForm() {
  const inputs = ["#inf-amount", "#inf-from", "#inf-to"];
  for (const sel of inputs) {
    $(sel).addEventListener("input", () => {
      readForm();
      renderSnippet();
      renderHero(null);
      writeUrl();
      scheduleCalc();
    });
  }
  $("#inf-country").addEventListener("change", () => {
    applyRangeForCountry($("#inf-country").value);
    readForm();
    renderSnippet();
    renderHero(null);
    writeUrl();
    scheduleCalc();
  });
  $("#inf-form").addEventListener("submit", (e) => {
    e.preventDefault();
    clearTimeout(calcTimer);
    calculate();
  });
}
