import { $ } from "./dom.js";
import { readForm, applyRangeForCountry } from "./form.js";
import { renderSnippet } from "./snippet.js";
import { renderHero } from "./result.js";
import { writeUrl } from "./url.js";
import { calculate } from "./calculate.js";
import { runFx } from "./fx.js";

let calcTimer = null;
function scheduleCalc() {
  clearTimeout(calcTimer);
  calcTimer = setTimeout(calculate, 200);
}

let fxTimer = null;
function scheduleFx() {
  clearTimeout(fxTimer);
  fxTimer = setTimeout(runFx, 200);
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

export function bindFxForm() {
  for (const sel of ["#fx-amount", "#fx-from", "#fx-to", "#fx-date"]) {
    $(sel).addEventListener("input", scheduleFx);
    $(sel).addEventListener("change", scheduleFx);
  }
  $("#fx-form").addEventListener("submit", (e) => {
    e.preventDefault();
    clearTimeout(fxTimer);
    runFx();
  });
}
