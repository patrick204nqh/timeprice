import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm, renderSnippet, renderHero, renderEmpty, compute, refreshRangeHint, refreshDateBounds } from "./compute.js";
import { writeUrl } from "./url.js";

let calcTimer = null;
function scheduleCalc() {
  clearTimeout(calcTimer);
  calcTimer = setTimeout(compute, 200);
}

const INPUT_SELECTORS = [
  "#calc-amount",
  "#from-currency", "#from-year", "#from-date",
  "#to-currency",   "#to-year",   "#to-date",
];

function onInput() {
  readForm();
  renderSnippet();
  // Clear the static result markup as soon as the user edits anything — the
  // pre-rendered "$242.09 USD" only matches the page defaults, and watching
  // it contradict a fresh "From" choice is the worst kind of stale.
  if (!state.vm) renderEmpty("Warming up Ruby VM…");
  else renderHero(null);
  refreshRangeHint();
  refreshDateBounds();
  writeUrl();
  scheduleCalc();
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

export function bindCalcForm() {
  for (const sel of INPUT_SELECTORS) {
    const el = $(sel);
    if (!el) continue;
    el.addEventListener("input", onInput);
    el.addEventListener("change", onInput);
  }

  const toggle = $("#precise-toggle");
  const wrap = $("#precise-wrap");
  if (toggle && wrap) {
    toggle.addEventListener("click", () => {
      wrap.hidden = !wrap.hidden;
      const label = $("#precise-toggle-label");
      const icon = $("#precise-toggle-icon");
      if (label) label.textContent = wrap.hidden ? "Use specific dates" : "Use year only";
      if (icon) icon.textContent = wrap.hidden ? "▸" : "▾";
      // Seed the day pickers with mid-year of the current year inputs when
      // the user opens the disclosure for the first time. Keeps the result
      // stable across the toggle.
      if (!wrap.hidden) {
        const fromYear = $("#from-year").value || "2010";
        const toYear = $("#to-year").value || fromYear;
        const fromDate = $("#from-date");
        const toDate = $("#to-date");
        if (fromDate && !fromDate.value) fromDate.value = `${fromYear}-06-15`;
        if (toDate && !toDate.value) toDate.value = `${toYear}-06-15`;
      }
      onInput();
    });
  }

  $("#calc-form").addEventListener("submit", (e) => {
    e.preventDefault();
    clearTimeout(calcTimer);
    compute();
  });
}

export function bindExampleChips() {
  const row = $("#example-chips");
  if (!row) return;
  row.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-example]");
    if (!btn) return;
    const [fromSpec, toSpec, amount] = btn.dataset.example.split("|");
    const [fromCur, fromDate] = fromSpec.split(":");
    const [toCur, toDate] = toSpec.split(":");
    $("#calc-amount").value = amount;
    $("#from-currency").value = fromCur;
    $("#to-currency").value = toCur;
    $("#from-year").value = fromDate;
    $("#to-year").value = toDate;
    // Reset to year-only when a chip is clicked — chips are the simple path.
    const wrap = $("#precise-wrap");
    if (wrap && !wrap.hidden) {
      wrap.hidden = true;
      $("#from-date").value = "";
      $("#to-date").value = "";
      const label = $("#precise-toggle-label");
      const icon = $("#precise-toggle-icon");
      if (label) label.textContent = "Use specific dates";
      if (icon) icon.textContent = "▸";
    }
    onInput();
  });
}
